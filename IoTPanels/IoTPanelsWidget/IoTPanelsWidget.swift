import WidgetKit
import SwiftUI
import Charts
import AppIntents

// MARK: - Timeline Entry

struct WidgetDesignEntry: TimelineEntry {
    let date: Date
    let designId: String?
    let designName: String
    let sizeType: WidgetSizeType
    let textScale: CGFloat
    let refreshMinutes: Int
    let backgroundColorHex: String
    let groups: [RenderedGroup]
    let isPlaceholder: Bool

    struct RenderedGroup: Identifiable {
        let id: String
        let title: String
        let style: PanelDisplayStyle
        let series: [ChartSeries]
        let styleConfig: StyleConfig
    }

    static var placeholder: WidgetDesignEntry {
        WidgetDesignEntry(
            date: Date(),
            designId: nil,
            designName: "My Widget",
            sizeType: .medium,
            textScale: 1.0,
            refreshMinutes: 15,
            backgroundColorHex: "#1C1C1E",
            groups: [
                RenderedGroup(id: "1", title: "Temperature", style: .chart, series: [
                    ChartSeries(id: "a", label: "Indoor", color: Color(hex: "#4A90D9"), dataPoints:
                        (0..<20).map { i in ChartDataPoint(time: Date().addingTimeInterval(Double(i - 20) * 300), value: 21 + sin(Double(i) * 0.3) * 2, field: "indoor") }
                    ),
                    ChartSeries(id: "b", label: "Outdoor", color: Color(hex: "#2ECC71"), dataPoints:
                        (0..<20).map { i in ChartDataPoint(time: Date().addingTimeInterval(Double(i - 20) * 300), value: 15 + sin(Double(i) * 0.4) * 3, field: "outdoor") }
                    ),
                ], styleConfig: .default),
                RenderedGroup(id: "2", title: "Battery", style: .singleValue, series: [
                    ChartSeries(id: "c", label: "level", color: .green, dataPoints: [ChartDataPoint(time: Date(), value: 87, field: "level")])
                ], styleConfig: .default),
            ],
            isPlaceholder: true
        )
    }

    static var empty: WidgetDesignEntry {
        WidgetDesignEntry(date: Date(), designId: nil, designName: "Select a widget", sizeType: .medium, textScale: 1.0, refreshMinutes: 15, backgroundColorHex: "#1C1C1E", groups: [], isPlaceholder: false)
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
    let homeName: String
    let isDemo: Bool

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Design"
    var displayRepresentation: DisplayRepresentation {
        let subtitle = homeName.isEmpty ? sizeLabel : "\(homeName) · \(sizeLabel)"
        return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
    static var defaultQuery = WidgetDesignEntityQuery()
}

struct WidgetDesignEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetDesignEntity] {
        let context = PersistenceController.shared.container.viewContext
        let designs = (try? context.fetch(WidgetDesign.fetchRequest())) ?? []
        return designs.compactMap { d -> WidgetDesignEntity? in
            guard let id = d.id?.uuidString, identifiers.contains(id) else { return nil }
            return WidgetDesignEntity(id: id, name: d.wrappedName, sizeLabel: d.wrappedSizeType.displayName, homeName: d.home?.name ?? "", isDemo: d.home?.isDemo ?? false)
        }
    }

    func suggestedEntities() async throws -> [WidgetDesignEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = WidgetDesign.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WidgetDesign.name, ascending: true)]
        let designs = (try? context.fetch(request)) ?? []
        return designs.compactMap { d -> WidgetDesignEntity? in
            guard let id = d.id?.uuidString else { return nil }
            return WidgetDesignEntity(id: id, name: d.wrappedName, sizeLabel: d.wrappedSizeType.displayName, homeName: d.home?.name ?? "", isDemo: d.home?.isDemo ?? false)
        }.sorted {
            if $0.isDemo != $1.isDemo { return !$0.isDemo }
            if $0.homeName != $1.homeName { return $0.homeName < $1.homeName }
            return $0.name < $1.name
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
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: entry.refreshMinutes, to: Date())!
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

        let allGroupData = await WidgetDataLoader.fetchAllGroups(for: design, cache: true)

        for group in design.resolvedGroups {
            let groupSeries = allGroupData[group.id] ?? []
            let config = group.items.first?.wrappedStyleConfig ?? .default
            renderedGroups.append(WidgetDesignEntry.RenderedGroup(id: group.id, title: group.title, style: group.style, series: groupSeries, styleConfig: config))
        }

        return WidgetDesignEntry(date: Date(), designId: design.id?.uuidString, designName: design.wrappedName, sizeType: design.wrappedSizeType, textScale: design.wrappedTextScale.factor, refreshMinutes: Int(design.refreshInterval), backgroundColorHex: design.wrappedBackgroundColorHex, groups: renderedGroups, isPlaceholder: false)
    }
}

// MARK: - Widget Views

struct WidgetCanvasFromEntry: View {
    let sizeType: WidgetSizeType
    let groups: [WidgetDesignEntry.RenderedGroup]
    var textScale: CGFloat = 1.0

    var body: some View {
        let visibleGroups = Array(groups.prefix(sizeType.maxCells))

        if visibleGroups.isEmpty {
            VStack {
                Image(systemName: "rectangle.on.rectangle.angled").font(.title2).foregroundStyle(.tertiary)
            }
        } else {
            gridLayout(groups: visibleGroups)
        }
    }

    private func gridLayout(groups: [WidgetDesignEntry.RenderedGroup]) -> some View {
        let columns = sizeType.gridColumns(for: groups.count)
        let rows = stride(from: 0, to: groups.count, by: columns).map {
            Array(groups[$0..<min($0 + columns, groups.count)])
        }
        let isCompact = sizeType != .large || columns > 1 || rows.count > 1

        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.id) { group in
                        groupCell(group, compact: isCompact)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func groupCell(_ group: WidgetDesignEntry.RenderedGroup, compact: Bool) -> some View {
        PanelRenderer(
            title: group.title,
            style: group.style,
            series: group.series,
            compact: compact,
            textScale: textScale,
            styleConfig: group.styleConfig,
            fillHeight: true
        )
        .frame(maxHeight: .infinity)
    }
}

struct DesignWidgetView: View {
    let entry: WidgetDesignEntry

    var body: some View {
        WidgetCanvasFromEntry(
            sizeType: entry.sizeType,
            groups: entry.groups,
            textScale: entry.textScale
        )
        .padding(10)
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
                .environmentObject(HeatmapSelectionState())
                .widgetURL(entry.designId.flatMap { URL(string: "iotpanels://widget/\($0)") })
                .containerBackground(for: .widget) { Color(hex: entry.backgroundColorHex) }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("IoT Panel")
        .description("Display a designed widget with live IoT data.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct IoTPanelsWidgetBundle: WidgetBundle {
    var body: some Widget {
        IoTPanelsWidget()
        SingleValueWidget()
        CountdownValueWidget()
        CountdownTransparentWidget()
    }
}
