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
    func fetchMeasurements() async throws -> [String]
    func fetchFieldKeys(measurement: String) async throws -> [String]
    func fetchTagKeys(measurement: String) async throws -> [String]
    func fetchTagValues(measurement: String, tag: String) async throws -> [String]
}

/// Creates the appropriate service for a DataSource based on its backend type.
enum ServiceFactory {
    static func service(for dataSource: DataSource) -> any DataSourceServiceProtocol {
        switch dataSource.wrappedBackendType {
        case .demo:
            return DemoService()
        case .influxDB1:
            return InfluxDB1Service(dataSource: dataSource)
        case .influxDB2:
            return InfluxDB2Service(dataSource: dataSource)
        case .influxDB3:
            return InfluxDB3Service(dataSource: dataSource)
        case .mqtt:
            #if canImport(CocoaMQTT)
            return MQTTService(dataSource: dataSource)
            #else
            return DemoService()
            #endif
        }
    }
}
