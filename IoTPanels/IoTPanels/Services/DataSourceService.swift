import Foundation

struct QueryResult {
    struct Column {
        let name: String
        let type: String
    }

    struct Row {
        let values: [String: String]
    }

    let columns: [Column]
    let rows: [Row]
}

protocol DataSourceServiceProtocol {
    func testConnection() async throws -> Bool
    func query(_ queryString: String) async throws -> QueryResult
}
