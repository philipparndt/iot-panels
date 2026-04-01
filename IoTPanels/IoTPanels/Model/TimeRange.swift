import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case twoHours = "2h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case fourteenDays = "14d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case oneYear = "365d"
    case twoYears = "730d"
    case fiveYears = "1825d"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twoHours: return "Last 2 hours"
        case .sixHours: return "Last 6 hours"
        case .twelveHours: return "Last 12 hours"
        case .twentyFourHours: return "Last 24 hours"
        case .sevenDays: return "Last 7 days"
        case .fourteenDays: return "Last 14 days"
        case .thirtyDays: return "Last 30 days"
        case .ninetyDays: return "Last 90 days"
        case .oneYear: return "Last 1 year"
        case .twoYears: return "Last 2 years"
        case .fiveYears: return "Last 5 years"
        }
    }

    var fluxValue: String {
        "-\(rawValue)"
    }

    /// The minimum aggregation window that keeps data points at a usable count.
    var minimumWindow: AggregateWindow {
        switch self {
        case .twoHours: return .none
        case .sixHours: return .oneMinute
        case .twelveHours: return .fiveMinutes
        case .twentyFourHours: return .fiveMinutes
        case .sevenDays: return .fifteenMinutes
        case .fourteenDays: return .oneHour
        case .thirtyDays: return .oneHour
        case .ninetyDays: return .oneDay
        case .oneYear: return .oneDay
        case .twoYears: return .twoDays
        case .fiveYears: return .sevenDays
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
    case twoHours = "2h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case oneDay = "1d"
    case twoDays = "2d"
    case sevenDays = "7d"
    case thirtyDays = "30d"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None (raw)"
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .sixHours: return "6 hours"
        case .twelveHours: return "12 hours"
        case .oneDay: return "1 day"
        case .twoDays: return "2 days"
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .none: return 0
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .oneHour: return 3600
        case .twoHours: return 7200
        case .sixHours: return 21600
        case .twelveHours: return 43200
        case .oneDay: return 86400
        case .twoDays: return 172800
        case .sevenDays: return 604800
        case .thirtyDays: return 2592000
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
        case .twoHours: return 5
        case .sixHours: return 6
        case .twelveHours: return 7
        case .oneDay: return 8
        case .twoDays: return 9
        case .sevenDays: return 10
        case .thirtyDays: return 11
        }
    }
}

enum ComparisonOffset: String, CaseIterable, Identifiable {
    case none = ""
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case fourteenDays = "14d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case oneYear = "365d"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .twentyFourHours: return "24 hours ago"
        case .sevenDays: return "7 days ago"
        case .fourteenDays: return "14 days ago"
        case .thirtyDays: return "30 days ago"
        case .ninetyDays: return "90 days ago"
        case .oneYear: return "1 year ago"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .none: return 0
        case .twentyFourHours: return 86400
        case .sevenDays: return 604800
        case .fourteenDays: return 1209600
        case .thirtyDays: return 2592000
        case .ninetyDays: return 7776000
        case .oneYear: return 31536000
        }
    }

    /// Flux duration string for the offset (e.g., "7d").
    var fluxValue: String { rawValue }
}

extension TimeRange {
    var seconds: TimeInterval {
        switch self {
        case .twoHours: return 7200
        case .sixHours: return 21600
        case .twelveHours: return 43200
        case .twentyFourHours: return 86400
        case .sevenDays: return 604800
        case .fourteenDays: return 1209600
        case .thirtyDays: return 2592000
        case .ninetyDays: return 7776000
        case .oneYear: return 31536000
        case .twoYears: return 63072000
        case .fiveYears: return 157680000
        }
    }
}
