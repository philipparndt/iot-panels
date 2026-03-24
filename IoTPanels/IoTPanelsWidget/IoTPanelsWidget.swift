import WidgetKit
import SwiftUI
import Charts
import AppIntents

// MARK: - Timeline Entry

struct WidgetDesignEntry: TimelineEntry {
    let date: Date
    let designName: String
    let sizeType: WidgetSizeType
    let groups: [RenderedGroup]
    let isPlaceholder: Bool

    struct RenderedGroup: Identifiable {
        let id: String
        let title: String
        let style: PanelDisplayStyle
        let series: [ChartSeries]
    }

    static var placeholder: WidgetDesignEntry {
        WidgetDesignEntry(
            date: Date(),
            designName: "My Widget",
            sizeType: .medium,
            groups: [
                RenderedGroup(id: "1", title: "Temperature", style: .chart, series: [
                    ChartSeries(id: "a", label: "Indoor", color: Color(hex: "#4A90D9"), dataPoints:
                        (0..<20).map { i in ChartDataPoint(time: Date().addingTimeInterval(Double(i - 20) * 300), value: 21 + sin(Double(i) * 0.3) * 2, field: "indoor") }
                    ),
                    ChartSeries(id: "b", label: "Outdoor", color: Color(hex: "#2ECC71"), dataPoints:
                        (0..<20).map { i in ChartDataPoint(time: Date().addingTimeInterval(Double(i - 20) * 300), value: 15 + sin(Double(i) * 0.4) * 3, field: "outdoor") }
                    ),
                ]),
                RenderedGroup(id: "2", title: "Battery", style: .singleValue, series: [
                    ChartSeries(id: "c", label: "level", color: .green, dataPoints: [ChartDataPoint(time: Date(), value: 87, field: "level")])
                ]),
            ],
            isPlaceholder: true
        )
    }

    static var empty: WidgetDesignEntry {
        WidgetDesignEntry(date: Date(), designName: "Select a widget", sizeType: .medium, groups: [], isPlaceholder: false)
    }
}

// MARK: - Intent

struct SelectWidgetDesignIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget Design"
    static var description: IntentDescription = "Choose a widget design to display."

    @Parameter(title: "Widget Design")
    var widgetDesign: WidgetDesignEntity?
}

struct WidgetDesignEntity: AppEntity {
    let id: String
    let name: String
    let sizeLabel: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Design"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(sizeLabel)")
    }
    static var defaultQuery = WidgetDesignEntityQuery()
}

struct WidgetDesignEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetDesignEntity] {
        let context = PersistenceController.shared.container.viewContext
        let designs = (try? context.fetch(WidgetDesign.fetchRequest())) ?? []
        return designs.compactMap { d in
            guard let id = d.id?.uuidString, identifiers.contains(id) else { return nil }
            return WidgetDesignEntity(id: id, name: d.wrappedName, sizeLabel: d.wrappedSizeType.displayName)
        }
    }

    func suggestedEntities() async throws -> [WidgetDesignEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = WidgetDesign.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WidgetDesign.name, ascending: true)]
        let designs = (try? context.fetch(request)) ?? []
        return designs.compactMap { d in
            guard let id = d.id?.uuidString else { return nil }
            return WidgetDesignEntity(id: id, name: d.wrappedName, sizeLabel: d.wrappedSizeType.displayName)
        }
    }

    func defaultResult() async -> WidgetDesignEntity? {
        try? await suggestedEntities().first
    }
}

// MARK: - Timeline Provider

struct WidgetDesignTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetDesignEntry
    typealias Intent = SelectWidgetDesignIntent

    func placeholder(in context: Context) -> WidgetDesignEntry { .placeholder }

    func snapshot(for configuration: SelectWidgetDesignIntent, in context: Context) async -> WidgetDesignEntry {
        context.isPreview ? .placeholder : await fetchEntry(for: configuration)
    }

    func timeline(for configuration: SelectWidgetDesignIntent, in context: Context) async -> Timeline<WidgetDesignEntry> {
        let entry = await fetchEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchEntry(for configuration: SelectWidgetDesignIntent) async -> WidgetDesignEntry {
        guard let entity = configuration.widgetDesign,
              let uuid = UUID(uuidString: entity.id) else { return .empty }

        let context = PersistenceController.shared.container.viewContext
        let request = WidgetDesign.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1

        guard let design = (try? context.fetch(request))?.first else { return .empty }

        var renderedGroups: [WidgetDesignEntry.RenderedGroup] = []

        for group in design.resolvedGroups {
            var groupSeries: [ChartSeries] = []
            for item in group.items {
                guard let query = item.savedQuery, let ds = query.dataSource else { continue }
                do {
                    let result = try await InfluxDB2Service(dataSource: ds).query(query.buildFluxQuery(bucket: ds.wrappedBucket))
                    let points = PanelCardView.parseChartData(result: result)
                    groupSeries.append(ChartSeries(id: item.wrappedId.uuidString, label: item.wrappedTitle, color: item.color, dataPoints: points))
                } catch {
                    groupSeries.append(ChartSeries(id: item.wrappedId.uuidString, label: item.wrappedTitle, color: item.color, dataPoints: []))
                }
            }
            renderedGroups.append(WidgetDesignEntry.RenderedGroup(id: group.id, title: group.title, style: group.style, series: groupSeries))
        }

        return WidgetDesignEntry(date: Date(), designName: design.wrappedName, sizeType: design.wrappedSizeType, groups: renderedGroups, isPlaceholder: false)
    }
}

// MARK: - Widget Views

struct DesignWidgetView: View {
    let entry: WidgetDesignEntry

    var body: some View {
        let visibleGroups = Array(entry.groups.prefix(entry.sizeType.maxCells))

        if visibleGroups.isEmpty {
            VStack {
                Image(systemName: "rectangle.on.rectangle.angled").font(.title2).foregroundStyle(.tertiary)
                Text(entry.designName).font(.caption).foregroundStyle(.secondary)
            }
        } else {
            switch entry.sizeType {
            case .small:
                if let g = visibleGroups.first {
                    groupCell(g, compact: false)
                }
            case .medium:
                HStack(spacing: 12) {
                    ForEach(Array(visibleGroups.enumerated()), id: \.element.id) { _, g in
                        groupCell(g, compact: visibleGroups.count > 1)
                            .frame(maxWidth: .infinity)
                    }
                }
            case .large:
                VStack(spacing: 8) {
                    ForEach(Array(visibleGroups.enumerated()), id: \.element.id) { _, g in
                        groupCell(g, compact: visibleGroups.count > 2)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    @ViewBuilder
    private func groupCell(_ group: WidgetDesignEntry.RenderedGroup, compact: Bool) -> some View {
        if group.series.count <= 1 {
            PanelRenderer(
                title: group.title,
                style: group.style,
                dataPoints: group.series.first?.dataPoints ?? [],
                compact: compact
            )
        } else {
            PanelRenderer(
                title: group.title,
                style: .chart,
                series: group.series,
                compact: compact
            )
        }
    }
}

// MARK: - Widget Configuration

struct IoTPanelsWidget: Widget {
    let kind: String = "IoTPanelsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectWidgetDesignIntent.self,
            provider: WidgetDesignTimelineProvider()
        ) { entry in
            DesignWidgetView(entry: entry)
                .padding()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("IoT Panel")
        .description("Display a designed widget with live IoT data.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct IoTPanelsWidgetBundle: WidgetBundle {
    var body: some Widget {
        IoTPanelsWidget()
    }
}
