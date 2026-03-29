import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct WatchValueEntry: TimelineEntry {
    let date: Date
    let queryName: String
    let value: Double?
    let unit: String
    let isPlaceholder: Bool
    let isCountdown: Bool

    var countdownTarget: Date? {
        guard isCountdown, let value, value > 0 else { return nil }
        return date.addingTimeInterval(value * 60)
    }

    static func placeholder(countdown: Bool) -> WatchValueEntry {
        WatchValueEntry(date: Date(), queryName: countdown ? "Dishwasher" : "Temperature",
                        value: countdown ? 45 : 21.5, unit: countdown ? "min" : "°C",
                        isPlaceholder: true, isCountdown: countdown)
    }

    static func empty(countdown: Bool) -> WatchValueEntry {
        WatchValueEntry(date: Date(), queryName: "Select a query", value: nil, unit: "",
                        isPlaceholder: false, isCountdown: countdown)
    }
}

// MARK: - Intent

struct WatchSelectQueryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Query"
    static var description: IntentDescription = "Choose a saved query to display."

    @Parameter(title: "Query")
    var savedQuery: WatchQueryEntity?
}

struct WatchQueryEntity: AppEntity {
    let id: String
    let name: String
    let unit: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Saved Query"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    static var defaultQuery = WatchQueryEntityQuery()
}

struct WatchQueryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WatchQueryEntity] {
        let context = PersistenceController.shared.container.viewContext
        let queries = (try? context.fetch(SavedQuery.fetchRequest())) ?? []
        return queries.compactMap { q in
            guard let id = q.id?.uuidString, identifiers.contains(id) else { return nil }
            return WatchQueryEntity(id: id, name: q.wrappedName, unit: q.wrappedUnit)
        }
    }

    func suggestedEntities() async throws -> [WatchQueryEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = SavedQuery.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedQuery.name, ascending: true)]
        let queries = (try? context.fetch(request)) ?? []
        return queries.compactMap { q in
            guard let id = q.id?.uuidString else { return nil }
            return WatchQueryEntity(id: id, name: q.wrappedName, unit: q.wrappedUnit)
        }
    }

    func defaultResult() async -> WatchQueryEntity? {
        try? await suggestedEntities().first
    }
}

// MARK: - Timeline Provider

struct WatchValueTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WatchValueEntry
    typealias Intent = WatchSelectQueryIntent

    let isCountdown: Bool

    func placeholder(in context: Context) -> WatchValueEntry { .placeholder(countdown: isCountdown) }

    func snapshot(for configuration: WatchSelectQueryIntent, in context: Context) async -> WatchValueEntry {
        context.isPreview ? .placeholder(countdown: isCountdown) : await fetchEntry(for: configuration)
    }

    func timeline(for configuration: WatchSelectQueryIntent, in context: Context) async -> Timeline<WatchValueEntry> {
        let entry = await fetchEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    func recommendations() -> [AppIntentRecommendation<WatchSelectQueryIntent>] {
        []
    }

    private func fetchEntry(for configuration: WatchSelectQueryIntent) async -> WatchValueEntry {
        guard let entity = configuration.savedQuery,
              let uuid = UUID(uuidString: entity.id) else { return .empty(countdown: isCountdown) }

        let context = PersistenceController.shared.container.viewContext
        let request = SavedQuery.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1

        guard let query = (try? context.fetch(request))?.first,
              let dataSource = query.dataSource else { return .empty(countdown: isCountdown) }

        do {
            let result = try await ServiceFactory.service(for: dataSource).query(query.buildQuery(for: dataSource))
            let points = ChartDataParser.parse(result: result)
            let lastValue = points.last?.value
            return WatchValueEntry(date: Date(), queryName: query.wrappedName, value: lastValue, unit: query.wrappedUnit, isPlaceholder: false, isCountdown: isCountdown)
        } catch {
            if let cached = query.cachedDataPoints, let lastValue = cached.last?.value {
                return WatchValueEntry(date: Date(), queryName: query.wrappedName, value: lastValue, unit: query.wrappedUnit, isPlaceholder: false, isCountdown: isCountdown)
            }
            return WatchValueEntry(date: Date(), queryName: query.wrappedName, value: nil, unit: query.wrappedUnit, isPlaceholder: false, isCountdown: isCountdown)
        }
    }
}

// MARK: - Helpers

private func formatValue(_ value: Double) -> String {
    abs(value - value.rounded()) < 0.01 ? String(format: "%.0f", value) : String(format: "%.1f", value)
}

// MARK: - Single Value View

struct WatchSingleValueView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchValueEntry

    var body: some View {
        if entry.value == nil && !entry.isPlaceholder {
            emptyView
        } else {
            switch family {
            case .accessoryInline:
                accessoryInlineView
            case .accessoryCircular:
                accessoryCircularView
            default:
                accessoryRectangularView
            }
        }
    }

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.queryName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .widgetAccentable()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatValue(entry.value ?? 0))
                    .font(.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if !entry.unit.isEmpty {
                    Text(entry.unit)
                        .font(.system(size: 10))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessoryCircularView: some View {
        VStack(spacing: 1) {
            Text(formatValue(entry.value ?? 0))
                .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if !entry.unit.isEmpty {
                Text(entry.unit)
                    .font(.system(size: 8))
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
        Text("Select query")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Countdown Value View

struct WatchCountdownValueView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchValueEntry

    var body: some View {
        if entry.value == nil && !entry.isPlaceholder {
            emptyView
        } else {
            switch family {
            case .accessoryInline:
                accessoryInlineView
            case .accessoryCircular:
                accessoryCircularView
            default:
                accessoryRectangularView
            }
        }
    }

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.queryName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .widgetAccentable()

            if let target = entry.countdownTarget {
                Text(target, style: .timer)
                    .font(.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text(formatValue(entry.value ?? 0))
                    .font(.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessoryCircularView: some View {
        VStack(spacing: 1) {
            if let target = entry.countdownTarget {
                Text(target, style: .timer)
                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
            } else {
                Text(formatValue(entry.value ?? 0))
                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .widgetAccentable()
    }

    @ViewBuilder
    private var accessoryInlineView: some View {
        if let target = entry.countdownTarget {
            Text("\(entry.queryName): \(target, style: .timer)")
        } else {
            Text("\(entry.queryName): \(formatValue(entry.value ?? 0))")
        }
    }

    private var emptyView: some View {
        Text("Select query")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Widget Configurations

struct WatchSingleValueWidget: Widget {
    let kind: String = "WatchSingleValueWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: WatchSelectQueryIntent.self,
            provider: WatchValueTimelineProvider(isCountdown: false)
        ) { entry in
            WatchSingleValueView(entry: entry)
                .containerBackground(for: .widget) { ContainerRelativeShape().fill(.tertiary) }
        }
        .configurationDisplayName("Single Value")
        .description("Display a single value from a saved query.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct WatchCountdownValueWidget: Widget {
    let kind: String = "WatchCountdownValueWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: WatchSelectQueryIntent.self,
            provider: WatchValueTimelineProvider(isCountdown: true)
        ) { entry in
            WatchCountdownValueView(entry: entry)
                .containerBackground(for: .widget) { ContainerRelativeShape().fill(.tertiary) }
        }
        .configurationDisplayName("Countdown Value")
        .description("Display a live countdown from a saved query (value in minutes).")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

@main
struct IoTPanelsWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchSingleValueWidget()
        WatchCountdownValueWidget()
    }
}
