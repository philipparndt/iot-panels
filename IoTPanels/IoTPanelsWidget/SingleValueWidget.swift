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

    /// When countdown mode is active, the value is treated as remaining minutes.
    var countdownTarget: Date? {
        guard isCountdown, let value, value > 0 else { return nil }
        return date.addingTimeInterval(value * 60)
    }

    static func placeholder(countdown: Bool) -> SingleValueEntry {
        SingleValueEntry(date: Date(), queryName: countdown ? "Dishwasher" : "Temperature",
                         value: countdown ? 45 : 21.5, unit: countdown ? "min" : "°C",
                         isPlaceholder: true, isCountdown: countdown)
    }

    static func empty(countdown: Bool) -> SingleValueEntry {
        SingleValueEntry(date: Date(), queryName: "Select a query", value: nil, unit: "",
                         isPlaceholder: false, isCountdown: countdown)
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

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Saved Query"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    static var defaultQuery = SavedQueryEntityQuery()
}

struct SavedQueryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SavedQueryEntity] {
        let context = PersistenceController.shared.container.viewContext
        let queries = (try? context.fetch(SavedQuery.fetchRequest())) ?? []
        return queries.compactMap { q in
            guard let id = q.id?.uuidString, identifiers.contains(id) else { return nil }
            return SavedQueryEntity(id: id, name: q.wrappedName, unit: q.wrappedUnit)
        }
    }

    func suggestedEntities() async throws -> [SavedQueryEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = SavedQuery.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedQuery.name, ascending: true)]
        let queries = (try? context.fetch(request)) ?? []
        return queries.compactMap { q in
            guard let id = q.id?.uuidString else { return nil }
            return SavedQueryEntity(id: id, name: q.wrappedName, unit: q.wrappedUnit)
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

    func placeholder(in context: Context) -> SingleValueEntry { .placeholder(countdown: isCountdown) }

    func snapshot(for configuration: SelectSavedQueryIntent, in context: Context) async -> SingleValueEntry {
        context.isPreview ? .placeholder(countdown: isCountdown) : await fetchEntry(for: configuration)
    }

    func timeline(for configuration: SelectSavedQueryIntent, in context: Context) async -> Timeline<SingleValueEntry> {
        let entry = await fetchEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchEntry(for configuration: SelectSavedQueryIntent) async -> SingleValueEntry {
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
            let points = PanelCardView.parseChartData(result: result)
            let lastValue = points.last?.value
            return SingleValueEntry(date: Date(), queryName: query.wrappedName, value: lastValue, unit: query.wrappedUnit, isPlaceholder: false, isCountdown: isCountdown)
        } catch {
            if let cached = query.cachedDataPoints, let lastValue = cached.last?.value {
                return SingleValueEntry(date: Date(), queryName: query.wrappedName, value: lastValue, unit: query.wrappedUnit, isPlaceholder: false, isCountdown: isCountdown)
            }
            return SingleValueEntry(date: Date(), queryName: query.wrappedName, value: nil, unit: query.wrappedUnit, isPlaceholder: false, isCountdown: isCountdown)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.queryName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formatValue(entry.value ?? 0))
                    .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if !entry.unit.isEmpty {
                    Text(entry.unit)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.queryName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let target = entry.countdownTarget {
                Text(target, style: .timer)
                    .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text(formatValue(entry.value ?? 0))
                    .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            provider: SingleValueTimelineProvider(isCountdown: false)
        ) { entry in
            SingleValueWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
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
            provider: SingleValueTimelineProvider(isCountdown: true)
        ) { entry in
            CountdownValueWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Countdown Value")
        .description("Display a live countdown from a saved query (value in minutes).")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
