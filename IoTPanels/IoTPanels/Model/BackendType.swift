import Foundation

enum BackendType: String, CaseIterable, Identifiable {
    case influxDB1
    case influxDB2
    case influxDB3
    case mqtt
    case prometheus
    case demo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .influxDB1: return "InfluxDB 1"
        case .influxDB2: return "InfluxDB 2"
        case .influxDB3: return "InfluxDB 3"
        case .mqtt: return "MQTT"
        case .prometheus: return "Prometheus"
        case .demo: return "Demo (Offline)"
        }
    }
}

enum PrometheusAuthMethod: String, CaseIterable, Identifiable {
    case none
    case basicAuth
    case bearerToken

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .basicAuth: return "Basic Auth"
        case .bearerToken: return "Bearer Token"
        }
    }
}

enum InfluxAuthMethod: String, CaseIterable, Identifiable {
    case token
    case usernamePassword

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .token: return "Token"
        case .usernamePassword: return "Username & Password"
        }
    }
}
