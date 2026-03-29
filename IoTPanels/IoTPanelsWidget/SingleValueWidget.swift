import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct SingleValueEntry: TimelineEntry {
    let date: Date
    let queryName: String
    let value: Double?
    let unit: String
    let isPlaceholder: Bool
    let isCountdown: Bool
    let hideWhenZero: Bool
    let showCompleted: Bool

    /// When countdown mode is active, the value is treated as remaining minutes.
    var countdownTarget: Date? {
        guard isCountdown, let value, value > 0 else { return nil }
        return date.addingTimeInterval(value * 60)
    }

    /// Whether this entry should be fully transparent.
    var isTransparent: Bool {
        hideWhenZero && !showCompleted && (value == nil || value == 0)
    }

    static func placeholder(countdown: Bool) -> SingleValueEntry {
        SingleValueEntry(date: Date(), queryName: countdown ? "Dishwasher" : "Temperature",
                         value: countdown ? 45 : 21.5, unit: countdown ? "min" : "°C",
                         isPlaceholder: true, isCountdown: countdown, hideWhenZero: false, showCompleted: false)
    }

    static func empty(countdown: Bool, hideWhenZero: Bool = false) -> SingleValueEntry {
        SingleValueEntry(date: Date(), queryName: "Select a query", value: nil, unit: "",
                         isPlaceholder: false, isCountdown: countdown, hideWhenZero: hideWhenZero, showCompleted: false)
    }
}

// MARK: - Intent

struct SelectSavedQueryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Query"
    static var description: IntentDescription = "Choose a saved query to display its latest value."

    @Parameter(title: "Query")
    var savedQuery: SavedQueryEntity?
}

struct SavedQueryEntity: AppEntity {
    let id: String
    let name: String
    let unit: String
    let dataSourceName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Saved Query"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(dataSourceName)")
    }
    static var defaultQuery = SavedQueryEntityQuery()
}

struct SavedQueryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SavedQueryEntity] {
        let context = PersistenceController.shared.container.viewContext
        let queries = (try? context.fetch(SavedQuery.fetchRequest())) ?? []
        return queries.compactMap { q in
            guard let id = q.id?.uuidString, identifiers.contains(id) else { return nil }
            return SavedQueryEntity(id: id, name: q.wrappedName, unit: q.wrappedUnit, dataSourceName: q.dataSource?.wrappedName ?? "")
        }
    }

    func suggestedEntities() async throws -> [SavedQueryEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = SavedQuery.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedQuery.name, ascending: true)]
        let queries = (try? context.fetch(request)) ?? []
        return queries.compactMap { q in
            guard let id = q.id?.uuidString else { return nil }
            return SavedQueryEntity(id: id, name: q.wrappedName, unit: q.wrappedUnit, dataSourceName: q.dataSource?.wrappedName ?? "")
        }
    }

    func defaultResult() async -> SavedQueryEntity? {
        try? await suggestedEntities().first
    }
}

// MARK: - Timeline Provider

struct SingleValueTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = SingleValueEntry
    typealias Intent = SelectSavedQueryIntent

    let isCountdown: Bool
    let hideWhenZero: Bool

    func placeholder(in context: Context) -> SingleValueEntry { .placeholder(countdown: isCountdown) }

    func snapshot(for configuration: SelectSavedQueryIntent, in context: Context) async -> SingleValueEntry {
        context.isPreview ? .placeholder(countdown: isCountdown) : await fetchEntryWithCacheInfo(for: configuration).0
    }

    func timeline(for configuration: SelectSavedQueryIntent, in context: Context) async -> Timeline<SingleValueEntry> {
        let (entry, cachedAt) = await fetchEntryWithCacheInfo(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!

        // For hideWhenZero mode: when value is 0, decide between "Completed" and transparent
        if hideWhenZero, let value = entry.value, value == 0 {
            let now = Date()
            let completedDeadline: Date
            if let cachedAt {
                // "Completed" expires 5 minutes after the value was first cached as 0
                completedDeadline = cachedAt.addingTimeInterval(5 * 60)
            } else {
                completedDeadline = now.addingTimeInterval(5 * 60)
            }

            if now >= completedDeadline {
                // Already past the 5-minute window — go straight to transparent
                let transparentEntry = SingleValueEntry(
                    date: now, queryName: entry.queryName, value: 0, unit: entry.unit,
                    isPlaceholder: false, isCountdown: true, hideWhenZero: true, showCompleted: false)
                return Timeline(entries: [transparentEntry], policy: .after(nextUpdate))
            } else {
                // Still within 5 minutes — show "Completed" then go transparent
                let completedEntry = SingleValueEntry(
                    date: now, queryName: entry.queryName, value: 0, unit: entry.unit,
                    isPlaceholder: false, isCountdown: true, hideWhenZero: true, showCompleted: true)
                let transparentEntry = SingleValueEntry(
                    date: completedDeadline, queryName: entry.queryName, value: 0, unit: entry.unit,
                    isPlaceholder: false, isCountdown: true, hideWhenZero: true, showCompleted: false)
                return Timeline(entries: [completedEntry, transparentEntry], policy: .after(nextUpdate))
            }
        }

        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchEntryWithCacheInfo(for configuration: SelectSavedQueryIntent) async -> (SingleValueEntry, Date?) {
        guard let entity = configuration.savedQuery,
              let uuid = UUID(uuidString: entity.id) else {
            return (.empty(countdown: isCountdown, hideWhenZero: hideWhenZero), nil)
        }

        let context = PersistenceController.shared.container.viewContext
        let request = SavedQuery.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1

        guard let query = (try? context.fetch(request))?.first,
              let dataSource = query.dataSource else {
            return (.empty(countdown: isCountdown, hideWhenZero: hideWhenZero), nil)
        }

        let cachedAt = query.wrappedCachedAt

        // Try live query first
        if let lastValue = await liveQueryValue(query: query, dataSource: dataSource) {
            let entry = SingleValueEntry(date: Date(), queryName: query.wrappedName, value: lastValue, unit: query.wrappedUnit, isPlaceholder: false, isCountdown: isCountdown, hideWhenZero: hideWhenZero, showCompleted: false)
            return (entry, query.wrappedCachedAt)
        }

        // Fall back to cached data
        if let cached = query.cachedDataPoints, let lastValue = cached.last?.value {
            let entry = SingleValueEntry(date: Date(), queryName: query.wrappedName, value: lastValue, unit: query.wrappedUnit, isPlaceholder: false, isCountdown: isCountdown, hideWhenZero: hideWhenZero, showCompleted: false)
            return (entry, cachedAt)
        }

        let entry = SingleValueEntry(date: Date(), queryName: query.wrappedName, value: nil, unit: query.wrappedUnit, isPlaceholder: false, isCountdown: isCountdown, hideWhenZero: hideWhenZero, showCompleted: false)
        return (entry, cachedAt)
    }

    private func liveQueryValue(query: SavedQuery, dataSource: DataSource) async -> Double? {
        do {
            let result = try await ServiceFactory.service(for: dataSource).query(query.buildQuery(for: dataSource))
            let points = ChartDataParser.parse(result: result)
            if let lastValue = points.last?.value {
                query.cacheResult(points)
                try? query.managedObjectContext?.save()
                return lastValue
            }
            return nil
        } catch {
            return nil
        }
    }
}

// MARK: - Shared Helpers

private func formatValue(_ value: Double) -> String {
    abs(value - value.rounded()) < 0.01 ? String(format: "%.0f", value) : String(format: "%.1f", value)
}

// MARK: - Single Value View

struct SingleValueWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SingleValueEntry

    var body: some View {
        if entry.value == nil && !entry.isPlaceholder {
            emptyView
        } else {
            switch family {
            case .accessoryInline:
                accessoryInlineView
            case .accessoryCircular:
                accessoryCircularView
            case .accessoryRectangular:
                accessoryRectangularView
            default:
                homeScreenView
            }
        }
    }

    private var homeScreenView: some View {
        VStack(spacing: 2) {
            Text(entry.queryName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(formatValue(entry.value ?? 0))
                .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if !entry.unit.isEmpty {
                Text(entry.unit)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.queryName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .widgetAccentable()

            Text(formatValue(entry.value ?? 0))
                .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if !entry.unit.isEmpty {
                Text(entry.unit)
                    .font(.system(size: 9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessoryCircularView: some View {
        VStack(spacing: 0) {
            Text(entry.queryName)
                .font(.system(size: 8, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(formatValue(entry.value ?? 0))
                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if !entry.unit.isEmpty {
                Text(entry.unit)
                    .font(.system(size: 7))
            }
        }
        .widgetAccentable()
    }

    private var accessoryInlineView: some View {
        let valueStr = formatValue(entry.value ?? 0)
        let unitStr = entry.unit.isEmpty ? "" : " \(entry.unit)"
        return Text("\(entry.queryName): \(valueStr)\(unitStr)")
    }

    private var emptyView: some View {
        VStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(entry.queryName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Countdown Value View

struct CountdownValueWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SingleValueEntry

    var body: some View {
        if entry.isTransparent {
            Color.clear
        } else if entry.value == nil && !entry.isPlaceholder {
            emptyView
        } else if entry.showCompleted {
            completedView
        } else {
            switch family {
            case .accessoryInline:
                accessoryInlineView
            case .accessoryCircular:
                accessoryCircularView
            case .accessoryRectangular:
                accessoryRectangularView
            default:
                homeScreenView
            }
        }
    }

    private var isCountingDown: Bool { entry.countdownTarget != nil }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 2) {
            Text(entry.queryName)
                .font(family == .accessoryCircular ? .system(size: 8, weight: .medium) :
                      family == .accessoryRectangular ? .system(size: 11, weight: .medium) :
                      .system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("Completed")
                .font(family == .accessoryCircular ? .system(size: 11, weight: .semibold) :
                      family == .accessoryRectangular ? .system(size: 16, weight: .semibold) :
                      .system(size: 24, weight: .semibold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Home Screen

    private var homeScreenView: some View {
        VStack(spacing: 2) {
            Text(entry.queryName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let target = entry.countdownTarget {
                Text(target, style: .timer)
                    .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text(formatValue(entry.value ?? 0))
                    .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            if !isCountingDown, !entry.unit.isEmpty {
                Text(entry.unit)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Lock Screen

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.queryName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .widgetAccentable()

            if let target = entry.countdownTarget {
                Text(target, style: .timer)
                    .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text(formatValue(entry.value ?? 0))
                    .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            if !isCountingDown, !entry.unit.isEmpty {
                Text(entry.unit)
                    .font(.system(size: 9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessoryCircularView: some View {
        VStack(spacing: 0) {
            Text(entry.queryName)
                .font(.system(size: 8, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let target = entry.countdownTarget {
                Text(target, style: .timer)
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
            } else {
                Text(formatValue(entry.value ?? 0))
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            if !isCountingDown, !entry.unit.isEmpty {
                Text(entry.unit)
                    .font(.system(size: 7))
            }
        }
        .widgetAccentable()
    }

    @ViewBuilder
    private var accessoryInlineView: some View {
        if let target = entry.countdownTarget {
            Text("\(entry.queryName): \(target, style: .timer)")
        } else {
            let unitStr = entry.unit.isEmpty ? "" : " \(entry.unit)"
            Text("\(entry.queryName): \(formatValue(entry.value ?? 0))\(unitStr)")
        }
    }

    private var emptyView: some View {
        VStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(entry.queryName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget Configurations

struct SingleValueWidget: Widget {
    let kind: String = "SingleValueWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectSavedQueryIntent.self,
            provider: SingleValueTimelineProvider(isCountdown: false, hideWhenZero: false)
        ) { entry in
            SingleValueWidgetView(entry: entry)
                .containerBackground(for: .widget) { ContainerRelativeShape().fill(.tertiary) }
        }
        .configurationDisplayName("Single Value")
        .description("Display a single value from a saved query.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct CountdownValueWidget: Widget {
    let kind: String = "CountdownValueWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectSavedQueryIntent.self,
            provider: SingleValueTimelineProvider(isCountdown: true, hideWhenZero: false)
        ) { entry in
            CountdownValueWidgetView(entry: entry)
                .containerBackground(for: .widget) { ContainerRelativeShape().fill(.tertiary) }
        }
        .configurationDisplayName("Countdown")
        .description("Display a live countdown from a saved query (value in minutes).")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct CountdownTransparentWidget: Widget {
    let kind: String = "CountdownTransparentWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectSavedQueryIntent.self,
            provider: SingleValueTimelineProvider(isCountdown: true, hideWhenZero: true)
        ) { entry in
            CountdownValueWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    if entry.isTransparent {
                        Color.clear
                    } else {
                        ContainerRelativeShape().fill(.tertiary)
                    }
                }
        }
        .configurationDisplayName("Countdown with Transparency")
        .description("Live countdown that shows \"Completed\" briefly, then hides when done.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
