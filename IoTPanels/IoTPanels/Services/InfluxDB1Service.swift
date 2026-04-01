import Foundation

struct InfluxDB1Service: DataSourceServiceProtocol {
    let url: String
    let database: String
    let username: String
    let password: String

    init(dataSource: DataSource) {
        self.url = dataSource.wrappedUrl
        self.database = dataSource.wrappedDatabase
        self.username = dataSource.wrappedUsername
        self.password = dataSource.wrappedPassword
    }

    init(url: String, database: String, username: String = "", password: String = "") {
        self.url = url
        self.database = database
        self.username = username
        self.password = password
    }

    // MARK: - Connection Test

    func testConnection() async throws -> Bool {
        let result = try await executeInfluxQL("SHOW DATABASES", db: nil)
        return !result.rows.isEmpty
    }

    // MARK: - Query

    func query(_ queryString: String) async throws -> QueryResult {
        return try await executeInfluxQL(queryString, db: database)
    }

    // MARK: - Database Discovery

    func fetchDatabases() async throws -> [String] {
        let result = try await executeInfluxQL("SHOW DATABASES", db: nil)
        return result.rows.compactMap { row in
            row.values["name"] ?? row.values.values.first
        }.filter { !$0.isEmpty && !$0.hasPrefix("_") }
    }

    // MARK: - Schema Discovery

    func fetchMeasurements() async throws -> [String] {
        let result = try await executeInfluxQL("SHOW MEASUREMENTS", db: database)
        return result.rows.compactMap { row in
            row.values["name"] ?? row.values.values.first
        }.filter { !$0.isEmpty }
    }

    func fetchFieldKeys(measurement: String) async throws -> [String] {
        let result = try await executeInfluxQL("SHOW FIELD KEYS FROM \"\(escapeIdentifier(measurement))\"", db: database)
        return result.rows.compactMap { row in
            row.values["fieldKey"] ?? row.values.values.first
        }.filter { !$0.isEmpty }
    }

    func fetchTagKeys(measurement: String) async throws -> [String] {
        let result = try await executeInfluxQL("SHOW TAG KEYS FROM \"\(escapeIdentifier(measurement))\"", db: database)
        return result.rows.compactMap { row in
            row.values["tagKey"] ?? row.values.values.first
        }.filter { !$0.isEmpty }
    }

    func fetchTagValues(measurement: String, tag: String) async throws -> [String] {
        let result = try await executeInfluxQL("SHOW TAG VALUES FROM \"\(escapeIdentifier(measurement))\" WITH KEY = \"\(escapeIdentifier(tag))\"", db: database)
        return result.rows.compactMap { row in
            row.values["value"] ?? row.values.values.first
        }.filter { !$0.isEmpty }
    }

    // MARK: - HTTP

    private func executeInfluxQL(_ q: String, db: String?) async throws -> QueryResult {
        var components = URLComponents(string: "\(url)/query")
        guard components != nil else {
            throw InfluxError.invalidURL
        }

        var queryItems = [URLQueryItem(name: "q", value: q)]
        if let db, !db.isEmpty {
            queryItems.append(URLQueryItem(name: "db", value: db))
        }
        if !username.isEmpty {
            queryItems.append(URLQueryItem(name: "u", value: username))
            queryItems.append(URLQueryItem(name: "p", value: password))
        }
        components!.queryItems = queryItems

        guard let requestUrl = components!.url else {
            throw InfluxError.invalidURL
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfluxError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfluxError.queryFailed(statusCode: httpResponse.statusCode, message: msg)
        }

        return parseInfluxDBResponse(data)
    }

    // MARK: - InfluxDB 1.x JSON Response Parsing

    /// Parses the InfluxDB 1.x JSON response format:
    /// `{"results":[{"series":[{"name":"...","columns":["time","value"],"values":[[ts,val],...]}]}]}`
    private func parseInfluxDBResponse(_ data: Data) -> QueryResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return QueryResult(columns: [], rows: [])
        }

        // Check for query errors
        if let firstResult = results.first,
           let error = firstResult["error"] as? String {
            // Return empty result — the error will surface through the status code path
            print("InfluxDB 1.x query error: \(error)")
            return QueryResult(columns: [], rows: [])
        }

        var allColumns: [QueryResult.Column] = []
        var allRows: [QueryResult.Row] = []

        for result in results {
            guard let seriesList = result["series"] as? [[String: Any]] else { continue }

            for series in seriesList {
                let columns = series["columns"] as? [String] ?? []
                let values = series["values"] as? [[Any]] ?? []
                let seriesName = series["name"] as? String

                if allColumns.isEmpty {
                    allColumns = columns.map { QueryResult.Column(name: $0, type: "string") }
                }

                for row in values {
                    var dict: [String: String] = [:]
                    for (i, col) in columns.enumerated() where i < row.count {
                        let val = row[i]
                        if val is NSNull { continue }
                        // Map InfluxDB column names to common names used by the chart parser
                        if col == "time" {
                            dict["_time"] = "\(val)"
                            dict["time"] = "\(val)"
                        } else {
                            dict[col] = "\(val)"
                            // For field queries, also set _value/_field for compatibility
                            if columns.count == 2 && col != "time" {
                                dict["_value"] = "\(val)"
                                dict["_field"] = seriesName ?? col
                            }
                        }
                    }
                    // For SHOW queries that return a single "name" or "key" column
                    if dict.isEmpty && row.count == 1 {
                        dict["name"] = "\(row[0])"
                    }
                    allRows.append(QueryResult.Row(values: dict))
                }
            }
        }

        return QueryResult(columns: allColumns, rows: allRows)
    }

    private func escapeIdentifier(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
