import Foundation

struct InfluxOrganization: Identifiable, Hashable {
    let id: String
    let name: String
}

struct InfluxBucket: Identifiable, Hashable {
    let id: String
    let name: String
    let orgID: String
}

struct InfluxDB2Service: DataSourceServiceProtocol {
    let url: String
    let token: String
    let organization: String
    let bucket: String

    init(dataSource: DataSource) {
        self.url = dataSource.wrappedUrl
        self.token = dataSource.wrappedToken
        self.organization = dataSource.wrappedOrganization
        self.bucket = dataSource.wrappedBucket
    }

    init(url: String, token: String, organization: String, bucket: String) {
        self.url = url
        self.token = token
        self.organization = organization
        self.bucket = bucket
    }

    func testConnection() async throws -> Bool {
        // Use /api/v2/buckets to verify both connectivity and token validity
        let endpoint = "\(url)/api/v2/buckets?limit=1"
        guard let requestUrl = URL(string: endpoint) else {
            throw InfluxError.invalidURL
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfluxError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return true
        case 401:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw InfluxError.authenticationFailed(statusCode: 401, message: body)
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw InfluxError.queryFailed(statusCode: httpResponse.statusCode, message: body)
        }
    }

    func query(_ queryString: String) async throws -> QueryResult {
        let encodedOrg = organization.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? organization
        let endpoint = "\(url)/api/v2/query?org=\(encodedOrg)"
        guard let requestUrl = URL(string: endpoint) else {
            throw InfluxError.invalidURL
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.flux", forHTTPHeaderField: "Content-Type")
        request.setValue("text/csv", forHTTPHeaderField: "Accept")
        request.httpBody = queryString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfluxError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfluxError.queryFailed(statusCode: httpResponse.statusCode, message: body)
        }

        let csv = String(data: data, encoding: .utf8) ?? ""
        return parseCSV(csv)
    }

    // MARK: - Schema Discovery

    func fetchMeasurements() async throws -> [String] {
        let flux = """
        import "influxdata/influxdb/schema"
        schema.measurements(bucket: "\(bucket)")
        """
        return try await queryValues(flux)
    }

    func fetchFieldKeys(measurement: String) async throws -> [String] {
        let flux = """
        import "influxdata/influxdb/schema"
        schema.measurementFieldKeys(bucket: "\(bucket)", measurement: "\(measurement)")
        """
        return try await queryValues(flux)
    }

    func fetchTagKeys(measurement: String) async throws -> [String] {
        let flux = """
        import "influxdata/influxdb/schema"
        schema.measurementTagKeys(bucket: "\(bucket)", measurement: "\(measurement)")
        """
        return try await queryValues(flux)
    }

    func fetchTagValues(measurement: String, tag: String) async throws -> [String] {
        let flux = """
        import "influxdata/influxdb/schema"
        schema.measurementTagValues(bucket: "\(bucket)", measurement: "\(measurement)", tag: "\(tag)")
        """
        return try await queryValues(flux)
    }

    private func queryValues(_ flux: String) async throws -> [String] {
        // Trim leading whitespace from each line (multi-line string indentation)
        let trimmedFlux = flux.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        let result = try await query(trimmedFlux)
        print("InfluxDB query result: \(result.columns.map(\.name)) — \(result.rows.count) rows")
        if let firstRow = result.rows.first {
            print("InfluxDB first row: \(firstRow.values)")
        }
        return result.rows.compactMap { $0.values["_value"] }.filter { !$0.isEmpty }
    }

    private func parseCSV(_ csv: String) -> QueryResult {
        let lines = csv.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n").filter { !$0.isEmpty && !$0.hasPrefix("#") }

        guard let headerLine = lines.first else {
            return QueryResult(columns: [], rows: [])
        }

        let headers = headerLine.components(separatedBy: ",")
        let columns = headers.map { QueryResult.Column(name: $0, type: "string") }

        let rows = lines.dropFirst().compactMap { line -> QueryResult.Row? in
            let values = line.components(separatedBy: ",")
            guard values.count == headers.count else { return nil }

            var dict: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                dict[header] = values[index]
            }
            return QueryResult.Row(values: dict)
        }

        return QueryResult(columns: columns, rows: rows)
    }
}

// MARK: - Session-based setup API

struct InfluxDB2SessionService {
    let url: String
    private let session: URLSession

    private let delegate = SessionDelegate()

    init(url: String) {
        self.url = url
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 15
        config.urlCredentialStorage = nil
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    func signIn(username: String, password: String) async throws {
        let endpoint = "\(url)/api/v2/signin"
        guard let requestUrl = URL(string: endpoint) else {
            throw InfluxError.invalidURL
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"

        let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfluxError.invalidResponse
        }

        guard httpResponse.statusCode == 204 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("InfluxDB sign-in failed: HTTP \(httpResponse.statusCode), body: \(body)")
            print("InfluxDB sign-in response headers: \(httpResponse.allHeaderFields)")
            throw InfluxError.authenticationFailed(statusCode: httpResponse.statusCode, message: body)
        }
    }

    func fetchOrganizations() async throws -> [InfluxOrganization] {
        let data = try await authenticatedGet("/api/v2/orgs")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let orgs = json["orgs"] as? [[String: Any]] else {
            throw InfluxError.invalidResponse
        }

        return orgs.compactMap { org in
            guard let id = org["id"] as? String,
                  let name = org["name"] as? String else { return nil }
            return InfluxOrganization(id: id, name: name)
        }
    }

    func fetchBuckets(orgID: String) async throws -> [InfluxBucket] {
        let data = try await authenticatedGet("/api/v2/buckets?orgID=\(orgID)")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buckets = json["buckets"] as? [[String: Any]] else {
            throw InfluxError.invalidResponse
        }

        return buckets.compactMap { bucket in
            guard let id = bucket["id"] as? String,
                  let name = bucket["name"] as? String,
                  let orgID = bucket["orgID"] as? String else { return nil }
            return InfluxBucket(id: id, name: name, orgID: orgID)
        }.filter { !$0.name.hasPrefix("_") }
    }

    func createToken(orgID: String, orgName: String, bucketID: String, bucketName: String, description: String) async throws -> String {
        let endpoint = "\(url)/api/v2/authorizations"
        guard let requestUrl = URL(string: endpoint) else {
            throw InfluxError.invalidURL
        }

        let body: [String: Any] = [
            "orgID": orgID,
            "description": description,
            "permissions": [
                [
                    "action": "read",
                    "resource": [
                        "type": "buckets",
                        "id": bucketID,
                        "orgID": orgID
                    ]
                ],
                [
                    "action": "write",
                    "resource": [
                        "type": "buckets",
                        "id": bucketID,
                        "orgID": orgID
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfluxError.invalidResponse
        }

        guard httpResponse.statusCode == 201 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfluxError.tokenCreationFailed(message: msg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            throw InfluxError.invalidResponse
        }

        return token
    }

    func signOut() async {
        guard let requestUrl = URL(string: "\(url)/api/v2/signout") else { return }
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        _ = try? await session.data(for: request)
    }

    // Delegate that prevents URLSession from intercepting HTTP auth challenges
    private class SessionDelegate: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            // Reject the challenge so our manual Authorization header is used as-is
            completionHandler(.rejectProtectionSpace, nil)
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            // Preserve Authorization header on redirects
            var newRequest = request
            if let auth = task.originalRequest?.value(forHTTPHeaderField: "Authorization") {
                newRequest.setValue(auth, forHTTPHeaderField: "Authorization")
            }
            completionHandler(newRequest)
        }
    }

    private func authenticatedGet(_ path: String) async throws -> Data {
        guard let requestUrl = URL(string: "\(url)\(path)") else {
            throw InfluxError.invalidURL
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfluxError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfluxError.queryFailed(statusCode: httpResponse.statusCode, message: msg)
        }

        return data
    }
}

enum InfluxError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed(statusCode: Int, message: String)
    case tokenCreationFailed(message: String)
    case queryFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationFailed(let statusCode, let message):
            let detail = message.isEmpty ? "" : " — \(message)"
            return "Authentication failed (HTTP \(statusCode))\(detail)"
        case .tokenCreationFailed(let message):
            return "Failed to create API token: \(message)"
        case .queryFailed(let statusCode, let message):
            return "Query failed (\(statusCode)): \(message)"
        }
    }
}
