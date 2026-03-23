import Foundation

enum BackendType: String, CaseIterable, Identifiable {
    case influxDB2

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .influxDB2: return "InfluxDB 2"
        }
    }
}
