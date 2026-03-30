import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case oneHour = "1h"
    case sixHours = "6h"
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case oneYear = "365d"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneHour: return "Last 1 hour"
        case .sixHours: return "Last 6 hours"
        case .twentyFourHours: return "Last 24 hours"
        case .sevenDays: return "Last 7 days"
        case .thirtyDays: return "Last 30 days"
        case .ninetyDays: return "Last 90 days"
        case .oneYear: return "Last 1 year"
        }
    }

    var fluxValue: String {
        "-\(rawValue)"
    }

    /// The minimum aggregation window that keeps data points at a usable count.
    var minimumWindow: AggregateWindow {
        switch self {
        case .oneHour: return .none
        case .sixHours: return .oneMinute
        case .twentyFourHours: return .fiveMinutes
        case .sevenDays: return .fifteenMinutes
        case .thirtyDays: return .oneHour
        case .ninetyDays: return .oneDay
        case .oneYear: return .oneDay
        }
    }

    /// Returns only the aggregate windows that make sense for this time range.
    var allowedWindows: [AggregateWindow] {
        let min = minimumWindow
        return AggregateWindow.allCases.filter { $0.sortOrder >= min.sortOrder }
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

    /// Used for filtering allowed windows per time range.
    var sortOrder: Int {
        switch self {
        case .none: return 0
        case .oneMinute: return 1
        case .fiveMinutes: return 2
        case .fifteenMinutes: return 3
        case .oneHour: return 4
        case .oneDay: return 5
        }
    }
}
