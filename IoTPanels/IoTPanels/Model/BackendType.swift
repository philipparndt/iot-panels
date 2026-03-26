import Foundation

enum BackendType: String, CaseIterable, Identifiable {
    case influxDB2
    case mqtt
    case demo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .influxDB2: return "InfluxDB 2"
        case .mqtt: return "MQTT"
        case .demo: return "Demo (Offline)"
        }
    }
}
