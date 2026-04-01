import Foundation

struct InfluxDB3Service: DataSourceServiceProtocol {
    let url: String
    let token: String
    let database: String

    init(dataSource: DataSource) {
        self.url = dataSource.wrappedUrl
        self.token = dataSource.wrappedToken
        self.database = dataSource.wrappedDatabase
    }

    init(url: String, token: String, database: String) {
        self.url = url
        self.token = token
        self.database = database
    }

    // MARK: - Connection Test

    func testConnection() async throws -> Bool {
        if database.isEmpty {
            // No database configured yet — just check the server is reachable
            _ = try await fetchDatabases()
            return true
        }
        let result = try await executeSQL("SELECT 1")
        return !result.rows.isEmpty
    }

    // MARK: - Query

    func query(_ queryString: String) async throws -> QueryResult {
        return try await executeSQL(queryString)
    }

    // MARK: - Database Discovery

    /// Lists all databases via the dedicated configure endpoint (no db required).
    func fetchDatabases() async throws -> [String] {
        let data = try await httpGet(path: "/api/v3/configure/database", queryItems: [
            URLQueryItem(name: "format", value: "json")
        ])
        let result = parseJSONResponse(data)
        return result.rows.compactMap { row in
            row.values["iox::database"] ?? row.values["database_name"] ?? row.values["name"] ?? row.values.values.first
        }.filter { !$0.isEmpty }
    }

    // MARK: - Schema Discovery

    func fetchMeasurements() async throws -> [String] {
        let result = try await executeSQL("SHOW TABLES")
        return result.rows.compactMap { row in
            row.values["table_name"] ?? row.values["name"] ?? row.values.values.first
        }.filter { !$0.isEmpty }
    }

    func fetchFieldKeys(measurement: String) async throws -> [String] {
        let result = try await executeSQL("SHOW COLUMNS FROM \"\(escapeSQLIdentifier(measurement))\"")
        return result.rows.compactMap { row in
            let name = row.values["column_name"] ?? row.values["name"] ?? ""
            let type = row.values["data_type"] ?? row.values["type"] ?? ""
            if name == "time" { return nil }
            if Self.isTagType(type) { return nil }
            return name.isEmpty ? nil : name
        }
    }

    func fetchTagKeys(measurement: String) async throws -> [String] {
        let result = try await executeSQL("SHOW COLUMNS FROM \"\(escapeSQLIdentifier(measurement))\"")
        return result.rows.compactMap { row in
            let name = row.values["column_name"] ?? row.values["name"] ?? ""
            let type = row.values["data_type"] ?? row.values["type"] ?? ""
            if name == "time" { return nil }
            if Self.isTagType(type) {
                return name.isEmpty ? nil : name
            }
            return nil
        }
    }

    /// Tags in InfluxDB 3 use `Dictionary(Int32, Utf8)` data type.
    private static func isTagType(_ dataType: String) -> Bool {
        dataType.hasPrefix("Dictionary(")
    }

    func fetchTagValues(measurement: String, tag: String) async throws -> [String] {
        let sql = "SELECT DISTINCT \"\(escapeSQLIdentifier(tag))\" FROM \"\(escapeSQLIdentifier(measurement))\" WHERE \"\(escapeSQLIdentifier(tag))\" IS NOT NULL ORDER BY \"\(escapeSQLIdentifier(tag))\" LIMIT 1000"
        let result = try await executeSQL(sql)
        return result.rows.compactMap { row in
            row.values[tag] ?? row.values.values.first
        }.filter { !$0.isEmpty }
    }

    // MARK: - HTTP

    /// Executes a SQL query via GET /api/v3/query_sql. The `db` parameter is always required.
    private func executeSQL(_ sql: String) async throws -> QueryResult {
        let data = try await httpGet(path: "/api/v3/query_sql", queryItems: [
            URLQueryItem(name: "db", value: database),
            URLQueryItem(name: "q", value: sql),
            URLQueryItem(name: "format", value: "json")
        ])
        return parseJSONResponse(data)
    }

    /// Generic authenticated GET request with query parameters.
    private func httpGet(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        var components = URLComponents(string: "\(url)\(path)")
        guard components != nil else {
            throw InfluxError.invalidURL
        }
        components!.queryItems = queryItems

        guard let requestUrl = components!.url else {
            throw InfluxError.invalidURL
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfluxError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfluxError.queryFailed(statusCode: httpResponse.statusCode, message: msg)
        }

        return data
    }

    // MARK: - JSON Parsing

    private func parseJSONResponse(_ data: Data) -> QueryResult {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            if let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rows = wrapper["results"] as? [[String: Any]] ?? wrapper["data"] as? [[String: Any]] {
                return parseRows(rows)
            }
            return QueryResult(columns: [], rows: [])
        }
        return parseRows(jsonArray)
    }

    private func parseRows(_ jsonRows: [[String: Any]]) -> QueryResult {
        guard let firstRow = jsonRows.first else {
            return QueryResult(columns: [], rows: [])
        }

        let columnNames = firstRow.keys.sorted()
        let columns = columnNames.map { QueryResult.Column(name: $0, type: "string") }

        let rows = jsonRows.map { obj in
            var values: [String: String] = [:]
            for (key, val) in obj {
                values[key] = "\(val)"
            }
            return QueryResult.Row(values: values)
        }

        return QueryResult(columns: columns, rows: rows)
    }

    private func escapeSQLIdentifier(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
