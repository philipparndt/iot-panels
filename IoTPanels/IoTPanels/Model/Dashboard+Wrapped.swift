import Foundation
import CoreData

enum PanelDisplayStyle: String, CaseIterable, Identifiable {
    case auto
    case chart
    case barChart
    case scatterChart
    case linePointChart
    case singleValue
    case gauge
    case calendarHeatmap
    case calendarHeatmapDense
    case bandChart

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .chart: return "Line"
        case .barChart: return "Bar"
        case .scatterChart: return "Scatter"
        case .linePointChart: return "Line + Points"
        case .singleValue: return "Value"
        case .gauge: return "Gauge"
        case .calendarHeatmap: return "Calendar"
        case .calendarHeatmapDense: return "Calendar Dense"
        case .bandChart: return "Band"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .chart: return "chart.xyaxis.line"
        case .barChart: return "chart.bar.fill"
        case .scatterChart: return "chart.dots.scatter"
        case .linePointChart: return "point.topleft.down.to.point.bottomright.curvepath"
        case .singleValue: return "number"
        case .gauge: return "gauge.medium"
        case .calendarHeatmap: return "calendar"
        case .calendarHeatmapDense: return "calendar.badge.clock"
        case .bandChart: return "chart.line.flattrend.xyaxis"
        }
    }

    var isLineBased: Bool {
        switch self {
        case .chart, .linePointChart, .bandChart: return true
        default: return false
        }
    }
}

extension Dashboard {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedName: String {
        get { name ?? "" }
        set { name = newValue }
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }

    var sortedPanels: [DashboardPanel] {
        let set = panels as? Set<DashboardPanel> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension DashboardPanel {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedTitle: String {
        get { title ?? "" }
        set { title = newValue }
    }

    var wrappedDisplayStyle: PanelDisplayStyle {
        get { PanelDisplayStyle(rawValue: displayStyle ?? "") ?? .auto }
        set { displayStyle = newValue.rawValue }
    }

    var wrappedStyleConfig: StyleConfig {
        get { StyleConfig.decode(from: styleConfigJSON) }
        set { styleConfigJSON = newValue.encode() }
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }

    // MARK: - Panel-local time/aggregation overrides (nil = use query default)

    var effectiveTimeRange: TimeRange {
        get {
            if let raw = timeRange, let val = TimeRange(rawValue: raw) { return val }
            return savedQuery?.wrappedTimeRange ?? .twoHours
        }
        set { timeRange = newValue.rawValue }
    }

    var effectiveAggregateWindow: AggregateWindow {
        get {
            if let raw = aggregateWindow, let val = AggregateWindow(rawValue: raw) { return val }
            return savedQuery?.wrappedAggregateWindow ?? .fiveMinutes
        }
        set { aggregateWindow = newValue.rawValue }
    }

    var effectiveAggregateFunction: AggregateFunction {
        get {
            if let raw = aggregateFunction, let val = AggregateFunction(rawValue: raw) { return val }
            return savedQuery?.wrappedAggregateFunction ?? .mean
        }
        set { aggregateFunction = newValue.rawValue }
    }

    var wrappedComparisonOffset: ComparisonOffset {
        get { ComparisonOffset(rawValue: comparisonOffset ?? "") ?? .none }
        set { comparisonOffset = newValue == .none ? nil : newValue.rawValue }
    }

    /// Whether this panel needs multi-aggregate queries (min/max/mean).
    var needsBandAggregates: Bool {
        wrappedDisplayStyle == .bandChart
    }
}
