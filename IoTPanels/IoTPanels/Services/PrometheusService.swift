import Foundation

enum PrometheusError: LocalizedError {
    case invalidURL
    case invalidResponse
    case queryFailed(statusCode: Int, message: String)
    case apiError(errorType: String, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .queryFailed(let statusCode, let message):
            return "Query failed (\(statusCode)): \(message)"
        case .apiError(let errorType, let message):
            return "\(errorType): \(message)"
        }
    }
}

struct PrometheusService: DataSourceServiceProtocol {
    let url: String
    let authMethod: PrometheusAuthMethod
    let token: String
    let username: String
    let password: String
    let enableSSL: Bool
    let allowUntrustedSSL: Bool

    init(dataSource: DataSource) {
        self.url = dataSource.wrappedUrl
        self.token = dataSource.wrappedToken
        self.username = dataSource.wrappedUsername
        self.password = dataSource.wrappedPassword
        self.enableSSL = dataSource.wrappedSsl
        self.allowUntrustedSSL = dataSource.wrappedUntrustedSSL

        // Determine auth method from stored credentials
        if !dataSource.wrappedToken.isEmpty {
            self.authMethod = .bearerToken
        } else if !dataSource.wrappedUsername.isEmpty {
            self.authMethod = .basicAuth
        } else {
            self.authMethod = .none
        }
    }

    init(url: String, authMethod: PrometheusAuthMethod = .none, token: String = "", username: String = "", password: String = "") {
        self.url = url
        self.authMethod = authMethod
        self.token = token
        self.username = username
        self.password = password
        self.enableSSL = false
        self.allowUntrustedSSL = false
    }

    // MARK: - Connection Test

    func testConnection() async throws -> Bool {
        let result = try await apiGet(path: "/api/v1/query", queryItems: [
            URLQueryItem(name: "query", value: "up")
        ])
        return result["status"] as? String == "success"
    }

    // MARK: - Query

    /// The query string may contain a time range prefix: `TIMERANGE:<seconds>|<promql>`.
    /// If no prefix is present, defaults to last 2 hours.
    func query(_ queryString: String) async throws -> QueryResult {
        let (promql, rangeSeconds) = Self.parseQueryString(queryString)
        let now = Date()
        let start = now.addingTimeInterval(-rangeSeconds)
        let step = stepForRange(seconds: rangeSeconds)

        return try await queryRange(query: promql, start: start, end: now, step: step)
    }

    /// Parses a query string that may contain a `TIMERANGE:<seconds>|` prefix.
    /// Returns the PromQL expression and time range in seconds.
    static func parseQueryString(_ queryString: String) -> (promql: String, rangeSeconds: TimeInterval) {
        if queryString.hasPrefix("TIMERANGE:"),
           let pipeIndex = queryString.firstIndex(of: "|") {
            let rangeStr = queryString[queryString.index(queryString.startIndex, offsetBy: 10)..<pipeIndex]
            let promql = String(queryString[queryString.index(after: pipeIndex)...])
            if let seconds = TimeInterval(rangeStr) {
                return (promql, seconds)
            }
        }
        return (queryString, 7200) // Default: 2 hours
    }

    // MARK: - Schema Discovery

    func fetchMeasurements() async throws -> [String] {
        let result = try await apiGet(path: "/api/v1/label/__name__/values", queryItems: [])
        guard let data = result["data"] as? [String] else {
            return []
        }
        return data.sorted()
    }

    func fetchFieldKeys(measurement: String) async throws -> [String] {
        // Prometheus metrics are single-valued
        return ["value"]
    }

    func fetchTagKeys(measurement: String) async throws -> [String] {
        let result = try await apiGet(path: "/api/v1/labels", queryItems: [
            URLQueryItem(name: "match[]", value: measurement)
        ])
        guard let data = result["data"] as? [String] else {
            return []
        }
        return data.filter { $0 != "__name__" }.sorted()
    }

    func fetchTagValues(measurement: String, tag: String) async throws -> [String] {
        let result = try await apiGet(path: "/api/v1/label/\(tag)/values", queryItems: [
            URLQueryItem(name: "match[]", value: measurement)
        ])
        guard let data = result["data"] as? [String] else {
            return []
        }
        return data.sorted()
    }

    // MARK: - Range Query

    func queryRange(query: String, start: Date, end: Date, step: String) async throws -> QueryResult {
        let result = try await apiGet(path: "/api/v1/query_range", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "start", value: "\(start.timeIntervalSince1970)"),
            URLQueryItem(name: "end", value: "\(end.timeIntervalSince1970)"),
            URLQueryItem(name: "step", value: step)
        ])

        guard let data = result["data"] as? [String: Any],
              let resultType = data["resultType"] as? String else {
            return QueryResult(columns: [], rows: [])
        }

        switch resultType {
        case "matrix":
            return parseMatrixResult(data)
        case "vector":
            return parseVectorResult(data)
        case "scalar":
            return parseScalarResult(data)
        default:
            return QueryResult(columns: [], rows: [])
        }
    }

    // MARK: - Result Parsing

    func parseMatrixResult(_ data: [String: Any]) -> QueryResult {
        guard let results = data["result"] as? [[String: Any]] else {
            return QueryResult(columns: [], rows: [])
        }

        // Collect all label keys across all series
        var allLabelKeys = Set<String>()
        for series in results {
            if let metric = series["metric"] as? [String: String] {
                for key in metric.keys where key != "__name__" {
                    allLabelKeys.insert(key)
                }
            }
        }

        let sortedLabelKeys = allLabelKeys.sorted()
        var columns = [QueryResult.Column(name: "time", type: "dateTime:RFC3339")]
        columns.append(QueryResult.Column(name: "value", type: "double"))
        for key in sortedLabelKeys {
            columns.append(QueryResult.Column(name: key, type: "string"))
        }

        var rows: [QueryResult.Row] = []
        for series in results {
            let metric = series["metric"] as? [String: String] ?? [:]
            guard let values = series["values"] as? [[Any]] else { continue }

            for point in values {
                guard point.count >= 2 else { continue }
                var rowValues: [String: String] = [:]

                // Parse timestamp
                if let timestamp = point[0] as? Double {
                    let date = Date(timeIntervalSince1970: timestamp)
                    rowValues["time"] = ISO8601DateFormatter().string(from: date)
                } else if let timestamp = point[0] as? Int {
                    let date = Date(timeIntervalSince1970: Double(timestamp))
                    rowValues["time"] = ISO8601DateFormatter().string(from: date)
                }

                // Parse value
                if let value = point[1] as? String {
                    rowValues["value"] = value
                }

                // Add label values
                for key in sortedLabelKeys {
                    rowValues[key] = metric[key] ?? ""
                }

                rows.append(QueryResult.Row(values: rowValues))
            }
        }

        return QueryResult(columns: columns, rows: rows)
    }

    func parseVectorResult(_ data: [String: Any]) -> QueryResult {
        guard let results = data["result"] as? [[String: Any]] else {
            return QueryResult(columns: [], rows: [])
        }

        var allLabelKeys = Set<String>()
        for series in results {
            if let metric = series["metric"] as? [String: String] {
                for key in metric.keys where key != "__name__" {
                    allLabelKeys.insert(key)
                }
            }
        }

        let sortedLabelKeys = allLabelKeys.sorted()
        var columns = [QueryResult.Column(name: "time", type: "dateTime:RFC3339")]
        columns.append(QueryResult.Column(name: "value", type: "double"))
        for key in sortedLabelKeys {
            columns.append(QueryResult.Column(name: key, type: "string"))
        }

        var rows: [QueryResult.Row] = []
        for series in results {
            let metric = series["metric"] as? [String: String] ?? [:]
            guard let value = series["value"] as? [Any], value.count >= 2 else { continue }

            var rowValues: [String: String] = [:]

            if let timestamp = value[0] as? Double {
                let date = Date(timeIntervalSince1970: timestamp)
                rowValues["time"] = ISO8601DateFormatter().string(from: date)
            }

            if let v = value[1] as? String {
                rowValues["value"] = v
            }

            for key in sortedLabelKeys {
                rowValues[key] = metric[key] ?? ""
            }

            rows.append(QueryResult.Row(values: rowValues))
        }

        return QueryResult(columns: columns, rows: rows)
    }

    func parseScalarResult(_ data: [String: Any]) -> QueryResult {
        guard let result = data["result"] as? [Any], result.count >= 2 else {
            return QueryResult(columns: [], rows: [])
        }

        let columns = [
            QueryResult.Column(name: "time", type: "dateTime:RFC3339"),
            QueryResult.Column(name: "value", type: "double")
        ]

        var rowValues: [String: String] = [:]
        if let timestamp = result[0] as? Double {
            let date = Date(timeIntervalSince1970: timestamp)
            rowValues["time"] = ISO8601DateFormatter().string(from: date)
        }
        if let v = result[1] as? String {
            rowValues["value"] = v
        }

        return QueryResult(columns: columns, rows: [QueryResult.Row(values: rowValues)])
    }

    // MARK: - Step Calculation

    /// Auto-calculates step based on the time range duration.
    func stepForRange(seconds: TimeInterval) -> String {
        // Target ~200-300 data points per query
        switch seconds {
        case ..<3600:         return "15s"    // < 1h  → ~240 points
        case ..<10800:        return "30s"    // < 3h  → ~360 points
        case ..<21600:        return "1m"     // < 6h  → ~360 points
        case ..<86400:        return "5m"     // < 24h → ~288 points
        case ..<604800:       return "30m"    // < 7d  → ~336 points
        case ..<2592000:      return "2h"     // < 30d → ~360 points
        case ..<7776000:      return "6h"     // < 90d → ~360 points
        default:              return "1d"     // 90d+  → variable
        }
    }

    // MARK: - HTTP

    private func apiGet(path: String, queryItems: [URLQueryItem]) async throws -> [String: Any] {
        var components = URLComponents(string: "\(url)\(path)")
        guard components != nil else {
            throw PrometheusError.invalidURL
        }
        if !queryItems.isEmpty {
            components!.queryItems = queryItems
        }

        guard let requestUrl = components!.url else {
            throw PrometheusError.invalidURL
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"

        // Auth headers
        switch authMethod {
        case .bearerToken:
            if !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        case .basicAuth:
            if !username.isEmpty {
                let credentials = "\(username):\(password)"
                if let data = credentials.data(using: .utf8) {
                    request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
                }
            }
        case .none:
            break
        }

        let session: URLSession
        if allowUntrustedSSL {
            let config = URLSessionConfiguration.default
            session = URLSession(configuration: config, delegate: InsecureSessionDelegate(), delegateQueue: nil)
        } else {
            session = URLSession.shared
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PrometheusError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PrometheusError.queryFailed(statusCode: httpResponse.statusCode, message: msg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PrometheusError.invalidResponse
        }

        if let status = json["status"] as? String, status == "error" {
            let errorType = json["errorType"] as? String ?? "unknown"
            let error = json["error"] as? String ?? "Unknown error"
            throw PrometheusError.apiError(errorType: errorType, message: error)
        }

        return json
    }
}

// MARK: - Insecure SSL Delegate

private final class InsecureSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: serverTrust))
        }
        return (.performDefaultHandling, nil)
    }
}

// MARK: - PromQL Builder

enum PromQLBuilder {
    /// Builds a PromQL expression from guided selections.
    static func build(
        metric: String,
        labelFilters: [String: Set<String>],
        aggregateFunction: String?
    ) -> String {
        var query = metric

        // Add label filters
        let filters = labelFilters
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .flatMap { key, values in
                if values.count == 1, let value = values.first {
                    return ["\(key)=\"\(escapePromQLLabel(value))\""]
                } else {
                    let regex = values.sorted().map { escapePromQLLabel($0) }.joined(separator: "|")
                    return ["\(key)=~\"\(regex)\""]
                }
            }

        if !filters.isEmpty {
            query += "{\(filters.joined(separator: ", "))}"
        }

        // Wrap with aggregate function
        if let fn = aggregateFunction, !fn.isEmpty, fn != "none" {
            query = "\(fn)(\(query))"
        }

        return query
    }

    private static func escapePromQLLabel(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
