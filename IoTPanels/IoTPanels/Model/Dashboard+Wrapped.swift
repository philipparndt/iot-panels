import Foundation
import CoreData
import SwiftUI

// MARK: - Panel Width Slot

/// User-facing intent for how much horizontal space a dashboard panel should
/// take. The slot is *not* a fixed fraction; it resolves to a row fraction at
/// render time based on the dashboard's horizontal size class. See
/// `PanelWidthSlot.fraction(for:)`.
enum PanelWidthSlot: String, CaseIterable, Identifiable {
    case small
    case medium
    case full

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:  return String(localized: "Small")
        case .medium: return String(localized: "Medium")
        case .full:   return String(localized: "Full width")
        }
    }

    /// Human-readable description of how this slot resolves on each device,
    /// shown in the picker so the user can never be surprised.
    var resolutionDescription: String {
        switch self {
        case .small:  return String(localized: "2 per row on iPhone, 4 per row on iPad")
        case .medium: return String(localized: "1 per row on iPhone, 2 per row on iPad")
        case .full:   return String(localized: "1 per row everywhere")
        }
    }

    /// Resolves the slot to a row fraction (0..1) for the given size class.
    func fraction(for sizeClass: UserInterfaceSizeClass?) -> Double {
        let isCompact = sizeClass != .regular
        switch self {
        case .small:  return isCompact ? 0.5 : 0.25
        case .medium: return isCompact ? 1.0 : 0.5
        case .full:   return 1.0
        }
    }
}

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
    case sparkline
    case stackedBar
    case stackedArea
    case statusIndicator
    case table
    case stateTimeline

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
        case .sparkline: return "Sparkline"
        case .stackedBar: return "Stacked Bar"
        case .stackedArea: return "Stacked Area"
        case .statusIndicator: return "Status"
        case .table: return "Table"
        case .stateTimeline: return "State Timeline"
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
        case .sparkline: return "waveform.path"
        case .stackedBar: return "chart.bar.xaxis.ascending"
        case .stackedArea: return "chart.line.uptrend.xyaxis"
        case .statusIndicator: return "circle.fill"
        case .table: return "tablecells"
        case .stateTimeline: return "rectangle.split.3x1.fill"
        }
    }

    var isLineBased: Bool {
        switch self {
        case .chart, .linePointChart, .bandChart, .sparkline: return true
        default: return false
        }
    }

    /// Config features supported by this chart type.
    var supportsThresholds: Bool {
        switch self {
        case .gauge, .stateTimeline, .text, .table: return false
        default: return true
        }
    }

    var supportsComparison: Bool { isLineBased }

    var supportsGaugeConfig: Bool { self == .gauge }

    var supportsHeatmapColor: Bool { self == .calendarHeatmap || self == .calendarHeatmapDense }

    var supportsBandConfig: Bool { self == .bandChart }

    var supportsStateConfig: Bool { self == .stateTimeline }

    var category: ChartCategory {
        switch self {
        case .chart, .barChart, .scatterChart, .linePointChart, .bandChart, .sparkline, .stackedBar, .stackedArea:
            return .timeSeries
        case .singleValue, .gauge, .circularGauge, .statusIndicator:
            return .values
        case .calendarHeatmap, .calendarHeatmapDense, .table:
            return .grid
        case .stateTimeline:
            return .timeSeries
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

    /// Width slots that this display style supports on the dashboard.
    ///
    /// - Compact value displays (single value, gauges, sparkline, text, status
    ///   indicator) support all three slots — they remain legible even at ¼
    ///   row width on iPad (~180pt).
    /// - Chart-type styles support `.medium` and `.full`. `.medium` resolves
    ///   to half width on iPad so two charts can share a row there, and to
    ///   full width on iPhone where there isn't room to split. `.small` is
    ///   excluded because ~180pt is too narrow for a readable chart.
    /// - Tables need the full row width for their columns and are pinned to
    ///   `.full`.
    var allowedWidthSlots: [PanelWidthSlot] {
        switch self {
        case .singleValue, .gauge, .circularGauge, .statusIndicator, .sparkline, .text:
            return [.small, .medium, .full]
        case .auto, .chart, .barChart, .scatterChart, .linePointChart, .bandChart,
             .stackedBar, .stackedArea, .calendarHeatmap, .calendarHeatmapDense,
             .stateTimeline:
            return [.medium, .full]
        case .table:
            return [.full]
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

    /// User-chosen width slot. `nil` (the default for any pre-existing or
    /// freshly-created panel) resolves to `.full`, preserving the original
    /// one-panel-per-row layout.
    var wrappedWidthSlot: PanelWidthSlot {
        get { PanelWidthSlot(rawValue: widthSlot ?? "") ?? .full }
        set { widthSlot = newValue == .full ? nil : newValue.rawValue }
    }

    /// User-chosen forced row break before this panel. The flag on the first
    /// panel in `sortOrder` is ignored by the renderer (there is no row to
    /// break from).
    var wrappedLineBreakBefore: Bool {
        get { lineBreakBefore }
        set { lineBreakBefore = newValue }
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
