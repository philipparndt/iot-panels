import Foundation
import SwiftUI

// MARK: - Widget Size

enum WidgetSizeType: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "2×2"
        case .medium: return "4×2"
        case .large: return "4×4"
        }
    }

    var iconName: String {
        switch self {
        case .small: return "square"
        case .medium: return "rectangle"
        case .large: return "square.fill"
        }
    }

    /// Preview aspect ratio (width/height)
    var aspectRatio: CGFloat {
        switch self {
        case .small: return 1.0
        case .medium: return 2.14
        case .large: return 0.95
        }
    }

    var maxCells: Int {
        switch self {
        case .small: return 1
        case .medium: return 6
        case .large: return 6
        }
    }

    /// Number of grid columns for auto-grid layout.
    func gridColumns(for itemCount: Int) -> Int {
        switch self {
        case .small: return 1
        case .medium: return itemCount <= 1 ? 1 : min(itemCount, 3)
        case .large: return itemCount <= 1 ? 1 : 2
        }
    }
}

// MARK: - Text Scale

enum TextScale: String, CaseIterable, Identifiable {
    case xs
    case small
    case medium
    case large
    case xl

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .xs: return "XS"
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .xl: return "XL"
        }
    }

    var factor: CGFloat {
        switch self {
        case .xs: return 0.75
        case .small: return 0.875
        case .medium: return 1.0
        case .large: return 1.15
        case .xl: return 1.3
        }
    }
}

// MARK: - Refresh Interval

enum RefreshInterval: CaseIterable, Identifiable {
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case sixHours

    var id: Int { minutes }

    var minutes: Int {
        switch self {
        case .fiveMinutes: return 5
        case .fifteenMinutes: return 15
        case .thirtyMinutes: return 30
        case .oneHour: return 60
        case .twoHours: return 120
        case .sixHours: return 360
        }
    }

    var displayName: String {
        switch self {
        case .fiveMinutes: return "5 min"
        case .fifteenMinutes: return "15 min"
        case .thirtyMinutes: return "30 min"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .sixHours: return "6 hours"
        }
    }

    static func from(minutes: Int) -> RefreshInterval {
        allCases.first { $0.minutes == minutes } ?? .fifteenMinutes
    }
}

// MARK: - Chart Series (multi-series rendering)

struct ChartSeries: Identifiable {
    let id: String
    let label: String
    let color: Color
    let dataPoints: [ChartDataPoint]
}

// MARK: - Render Group (items grouped by groupTag)

struct WidgetRenderGroup: Identifiable {
    let id: String
    let title: String
    let style: PanelDisplayStyle
    let items: [WidgetDesignItem]
}

// MARK: - WidgetDesign

extension WidgetDesign {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedName: String {
        get { name ?? "" }
        set { name = newValue }
    }

    var wrappedSizeType: WidgetSizeType {
        get { WidgetSizeType(rawValue: sizeType ?? "") ?? .medium }
        set { sizeType = newValue.rawValue }
    }

    var wrappedTextScale: TextScale {
        get { TextScale(rawValue: textScale ?? "") ?? .medium }
        set { textScale = newValue.rawValue }
    }

    static let adaptiveBackgroundHex = "#ADAPTIVE"

    var wrappedBackgroundColorHex: String {
        get { backgroundColorHex ?? "#1C1C1E" }
        set { backgroundColorHex = newValue }
    }

    var backgroundColor: Color {
        if wrappedBackgroundColorHex == Self.adaptiveBackgroundHex {
            #if os(macOS)
            return Color(NSColor.windowBackgroundColor)
            #else
            return Color(uiColor: .systemBackground)
            #endif
        }
        return Color(hex: wrappedBackgroundColorHex)
    }

    var wrappedRefreshInterval: RefreshInterval {
        get { RefreshInterval.from(minutes: Int(refreshInterval)) }
        set { refreshInterval = Int32(newValue.minutes) }
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }

    var sortedItems: [WidgetDesignItem] {
        let set = items as? Set<WidgetDesignItem> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Group items by groupTag. Ungrouped items (nil/empty groupTag) each become their own group.
    var resolvedGroups: [WidgetRenderGroup] {
        var groups: [WidgetRenderGroup] = []
        var seenGroups: [String: Int] = [:]

        for item in sortedItems {
            let tag = item.groupTag ?? ""
            if !tag.isEmpty, let existingIdx = seenGroups[tag] {
                let existing = groups[existingIdx]
                var updatedItems = existing.items
                updatedItems.append(item)
                groups[existingIdx] = WidgetRenderGroup(
                    id: existing.id,
                    title: existing.title,
                    style: existing.style,
                    items: updatedItems
                )
            } else if !tag.isEmpty {
                seenGroups[tag] = groups.count
                groups.append(WidgetRenderGroup(
                    id: tag,
                    title: wrappedName,
                    style: item.wrappedDisplayStyle,
                    items: [item]
                ))
            } else {
                groups.append(WidgetRenderGroup(
                    id: item.wrappedId.uuidString,
                    title: item.wrappedTitle,
                    style: item.wrappedDisplayStyle,
                    items: [item]
                ))
            }
        }

        return groups
    }
}

// MARK: - WidgetDesignItem

extension WidgetDesignItem {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedTitle: String {
        get { (title?.isEmpty ?? true) ? (savedQuery?.wrappedName ?? "") : (title ?? "") }
        set { title = newValue }
    }

    var wrappedDisplayStyle: PanelDisplayStyle {
        get { PanelDisplayStyle(rawValue: displayStyle ?? "") ?? .chart }
        set { displayStyle = newValue.rawValue }
    }

    var wrappedColorHex: String {
        get { colorHex ?? SeriesColors.palette[0] }
        set { colorHex = newValue }
    }

    var color: Color {
        Color(hex: wrappedColorHex)
    }

    var wrappedStyleConfig: StyleConfig {
        get { StyleConfig.decode(from: styleConfigJSON) }
        set { styleConfigJSON = newValue.encode() }
    }

    // MARK: - Query override properties (mirror DashboardPanel pattern)

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

    var needsBandAggregates: Bool {
        wrappedDisplayStyle == .bandChart
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }

    // MARK: - Data cache

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

    // MARK: - Query building (mirrors SavedQuery.buildQuery(for:panel:))

    func buildQuery(for dataSource: DataSource) -> String? {
        guard let query = savedQuery else { return nil }
        if query.wrappedIsRawQuery { return query.wrappedRawQuery }
        let tr = effectiveTimeRange
        let aw = effectiveAggregateWindow
        let af = effectiveAggregateFunction

        switch dataSource.wrappedBackendType {
        case .influxDB1:
            return needsBandAggregates
                ? query.buildBandInfluxQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw)
                : query.buildInfluxQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, fn: af)
        case .influxDB2:
            return needsBandAggregates
                ? query.buildBandFluxQuery(bucket: dataSource.wrappedBucket, timeRange: tr, window: aw)
                : query.buildFluxQuery(bucket: dataSource.wrappedBucket, timeRange: tr, window: aw, fn: af)
        case .influxDB3:
            return needsBandAggregates
                ? query.buildBandSQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw)
                : query.buildSQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, fn: af)
        case .prometheus:
            return query.buildPrometheusQuery(timeRange: effectiveTimeRange)
        case .mqtt:
            #if canImport(CocoaMQTT)
            return query.buildMQTTQuery()
            #else
            return nil
            #endif
        case .demo:
            return needsBandAggregates
                ? query.buildBandFluxQuery(bucket: "demo", timeRange: tr, window: aw)
                : query.buildFluxQuery(bucket: "demo", timeRange: tr, window: aw, fn: af)
        }
    }

    func buildComparisonQuery(for dataSource: DataSource) -> String? {
        guard let query = savedQuery, !query.wrappedIsRawQuery else { return nil }
        let offset = wrappedComparisonOffset
        guard offset != .none else { return nil }
        let tr = effectiveTimeRange
        let aw = effectiveAggregateWindow
        let af = effectiveAggregateFunction

        switch dataSource.wrappedBackendType {
        case .influxDB1:
            return needsBandAggregates
                ? query.buildComparisonBandInfluxQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, offset: offset)
                : query.buildComparisonInfluxQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, fn: af, offset: offset)
        case .influxDB2:
            return needsBandAggregates
                ? query.buildComparisonBandFluxQuery(bucket: dataSource.wrappedBucket, timeRange: tr, window: aw, offset: offset)
                : query.buildComparisonFluxQuery(bucket: dataSource.wrappedBucket, timeRange: tr, window: aw, fn: af, offset: offset)
        case .influxDB3:
            return needsBandAggregates
                ? query.buildComparisonBandSQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, offset: offset)
                : query.buildComparisonSQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, fn: af, offset: offset)
        case .prometheus:
            return nil
        case .mqtt:
            return nil
        case .demo:
            return needsBandAggregates
                ? query.buildComparisonBandFluxQuery(bucket: "demo", timeRange: tr, window: aw, offset: offset)
                : query.buildComparisonFluxQuery(bucket: "demo", timeRange: tr, window: aw, fn: af, offset: offset)
        }
    }
}
