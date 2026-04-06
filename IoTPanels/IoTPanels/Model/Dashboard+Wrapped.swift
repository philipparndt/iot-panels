import Foundation
import CoreData

enum ChartCategory: String, CaseIterable, Identifiable {
    case timeSeries
    case values
    case grid
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .timeSeries: return "Time Series"
        case .values: return "Values"
        case .grid: return "Grid"
        case .other: return "Other"
        }
    }

    var sortOrder: Int {
        switch self {
        case .timeSeries: return 0
        case .values: return 1
        case .grid: return 2
        case .other: return 3
        }
    }
}

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
    case circularGauge
    case text

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
        case .circularGauge: return "Circular Gauge"
        case .text: return "Text"
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
        case .circularGauge: return "gauge.open.with.lines.needle.33percent"
        case .text: return "textformat"
        }
    }

    var isLineBased: Bool {
        switch self {
        case .chart, .linePointChart, .bandChart: return true
        default: return false
        }
    }

    var category: ChartCategory {
        switch self {
        case .chart, .barChart, .scatterChart, .linePointChart, .bandChart:
            return .timeSeries
        case .singleValue, .gauge, .circularGauge:
            return .values
        case .calendarHeatmap, .calendarHeatmapDense:
            return .grid
        case .auto, .text:
            return .other
        }
    }

    static func grouped() -> [(category: ChartCategory, styles: [PanelDisplayStyle])] {
        let grouped = Dictionary(grouping: allCases) { $0.category }
        return ChartCategory.allCases
            .filter { grouped[$0] != nil }
            .map { (category: $0, styles: grouped[$0]!) }
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

    // MARK: - Panel-level data cache

    func cacheResult(_ dataPoints: [ChartDataPoint]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        cachedResultJSON = (try? String(data: encoder.encode(dataPoints), encoding: .utf8)) ?? "[]"
        cachedAt = Date()
    }

    var cachedDataPoints: [ChartDataPoint]? {
        guard let json = cachedResultJSON, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([ChartDataPoint].self, from: data)
    }

    var wrappedCachedAt: Date? {
        cachedAt
    }

    func cacheComparisonResult(_ dataPoints: [ChartDataPoint]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        cachedComparisonJSON = (try? String(data: encoder.encode(dataPoints), encoding: .utf8)) ?? "[]"
    }

    var cachedComparisonDataPoints: [ChartDataPoint]? {
        guard let json = cachedComparisonJSON, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([ChartDataPoint].self, from: data)
    }

    func clearComparisonCache() {
        cachedComparisonJSON = nil
    }
}
