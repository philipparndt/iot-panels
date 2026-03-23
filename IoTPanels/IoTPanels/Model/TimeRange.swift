import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case oneHour = "1h"
    case sixHours = "6h"
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneHour: return "Last 1 hour"
        case .sixHours: return "Last 6 hours"
        case .twentyFourHours: return "Last 24 hours"
        case .sevenDays: return "Last 7 days"
        case .thirtyDays: return "Last 30 days"
        }
    }

    var fluxValue: String {
        "-\(rawValue)"
    }
}

enum AggregateFunction: String, CaseIterable, Identifiable {
    case mean
    case last
    case max
    case min
    case sum

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

enum AggregateWindow: String, CaseIterable, Identifiable {
    case none = "none"
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case oneHour = "1h"
    case oneDay = "1d"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None (raw)"
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .oneHour: return "1 hour"
        case .oneDay: return "1 day"
        }
    }
}
