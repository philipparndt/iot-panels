import WidgetKit
import SwiftUI
import Charts
import AppIntents

// MARK: - Data Models

enum PanelDisplayMode {
    case singleValue
    case chart
    case noData
}

struct PanelData {
    let title: String
    let dataPoints: [WidgetChartPoint]
    let lastValue: String?
    let fieldName: String?
    let unit: String?

    var displayMode: PanelDisplayMode {
        if dataPoints.isEmpty && lastValue == nil { return .noData }
        if dataPoints.count <= 2 { return .singleValue }
        return .chart
    }

    var trend: Trend {
        guard dataPoints.count >= 2 else { return .stable }
        let recent = dataPoints.suffix(max(dataPoints.count / 4, 2))
        let older = dataPoints.prefix(max(dataPoints.count / 4, 2))
        let recentAvg = recent.map(\.value).reduce(0, +) / Double(recent.count)
        let olderAvg = older.map(\.value).reduce(0, +) / Double(older.count)
        let diff = recentAvg - olderAvg
        let threshold = abs(olderAvg) * 0.02
        if diff > threshold { return .up }
        if diff < -threshold { return .down }
        return .stable
    }

    enum Trend {
        case up, down, stable

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: return .red
            case .down: return .blue
            case .stable: return .secondary
            }
        }
    }
}

struct DashboardEntry: TimelineEntry {
    let date: Date
    let dashboardName: String
    let panels: [PanelData]
    let isPlaceholder: Bool

    static var placeholder: DashboardEntry {
        DashboardEntry(
            date: Date(),
            dashboardName: "My Dashboard",
            panels: [
                PanelData(
                    title: "Temperature",
                    dataPoints: (0..<20).map { i in
                        WidgetChartPoint(
                            time: Date().addingTimeInterval(Double(i - 20) * 300),
                            value: 20.0 + sin(Double(i) * 0.3) * 2,
                            field: "value"
                        )
                    },
                    lastValue: "21.3",
                    fieldName: "temperature",
                    unit: nil
                ),
                PanelData(
                    title: "Dishwasher",
                    dataPoints: [],
                    lastValue: "42",
                    fieldName: "remaining_min",
                    unit: "min"
                ),
            ],
            isPlaceholder: true
        )
    }

    static var empty: DashboardEntry {
        DashboardEntry(
            date: Date(),
            dashboardName: "Select a dashboard",
            panels: [],
            isPlaceholder: false
        )
    }
}

struct WidgetChartPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
    let field: String
}

// MARK: - Intent

struct SelectDashboardIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Dashboard"
    static var description: IntentDescription = "Choose a dashboard to display."

    @Parameter(title: "Dashboard")
    var dashboard: DashboardEntity?
}

struct DashboardEntity: AppEntity {
    let id: String
    let name: String
    let panelCount: Int

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Dashboard"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(panelCount) panels")
    }

    static var defaultQuery = DashboardEntityQuery()
}

struct DashboardEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DashboardEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = Dashboard.fetchRequest()
        let dashboards = (try? context.fetch(request)) ?? []

        return dashboards.compactMap { dashboard in
            guard let id = dashboard.id?.uuidString,
                  identifiers.contains(id) else { return nil }
            return DashboardEntity(id: id, name: dashboard.wrappedName, panelCount: dashboard.sortedPanels.count)
        }
    }

    func suggestedEntities() async throws -> [DashboardEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = Dashboard.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Dashboard.name, ascending: true)]
        let dashboards = (try? context.fetch(request)) ?? []

        return dashboards.compactMap { dashboard in
            guard let id = dashboard.id?.uuidString else { return nil }
            return DashboardEntity(id: id, name: dashboard.wrappedName, panelCount: dashboard.sortedPanels.count)
        }
    }

    func defaultResult() async -> DashboardEntity? {
        try? await suggestedEntities().first
    }
}

// MARK: - Timeline Provider

struct DashboardTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = DashboardEntry
    typealias Intent = SelectDashboardIntent

    func placeholder(in context: Context) -> DashboardEntry { .placeholder }

    func snapshot(for configuration: SelectDashboardIntent, in context: Context) async -> DashboardEntry {
        context.isPreview ? .placeholder : await fetchEntry(for: configuration)
    }

    func timeline(for configuration: SelectDashboardIntent, in context: Context) async -> Timeline<DashboardEntry> {
        let entry = await fetchEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchEntry(for configuration: SelectDashboardIntent) async -> DashboardEntry {
        guard let entity = configuration.dashboard,
              let uuid = UUID(uuidString: entity.id) else { return .empty }

        let context = PersistenceController.shared.container.viewContext
        let request = Dashboard.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1

        guard let dashboard = (try? context.fetch(request))?.first else { return .empty }

        var panelDataList: [PanelData] = []

        for panel in dashboard.sortedPanels {
            guard let query = panel.savedQuery,
                  let dataSource = query.dataSource else {
                panelDataList.append(PanelData(title: panel.wrappedTitle, dataPoints: [], lastValue: nil, fieldName: nil, unit: nil))
                continue
            }

            let service = InfluxDB2Service(dataSource: dataSource)
            let flux = query.buildFluxQuery(bucket: dataSource.wrappedBucket)

            do {
                let result = try await service.query(flux)
                let dataPoints = parseDataPoints(result: result)
                let lastValue = dataPoints.last.map { String(format: fitsInteger($0.value) ? "%.0f" : "%.1f", $0.value) }
                let fieldName = dataPoints.first?.field
                panelDataList.append(PanelData(title: panel.wrappedTitle, dataPoints: dataPoints, lastValue: lastValue, fieldName: fieldName, unit: nil))
            } catch {
                panelDataList.append(PanelData(title: panel.wrappedTitle, dataPoints: [], lastValue: nil, fieldName: nil, unit: nil))
            }
        }

        return DashboardEntry(date: Date(), dashboardName: dashboard.wrappedName, panels: panelDataList, isPlaceholder: false)
    }

    private func fitsInteger(_ value: Double) -> Bool {
        abs(value - value.rounded()) < 0.01
    }

    private func parseDataPoints(result: QueryResult) -> [WidgetChartPoint] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        return result.rows.compactMap { row in
            guard let timeStr = row.values["_time"],
                  let valueStr = row.values["_value"],
                  let value = Double(valueStr) else { return nil }
            guard let time = formatter.date(from: timeStr) ?? fallback.date(from: timeStr) else { return nil }
            return WidgetChartPoint(time: time, value: value, field: row.values["_field"] ?? "value")
        }
    }
}

// MARK: - Panel Cell Views

struct SingleValueCell: View {
    let panel: PanelData
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text(panel.title)
                .font(compact ? .system(size: 10, weight: .medium) : .caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(panel.lastValue ?? "—")
                    .font(compact ? .title3.weight(.semibold).monospacedDigit() : .title.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if let unit = panel.unit ?? panel.fieldName {
                    Text(unit)
                        .font(compact ? .system(size: 9) : .caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if panel.dataPoints.count >= 2 {
                HStack(spacing: 2) {
                    Image(systemName: panel.trend.icon)
                        .font(.system(size: 9, weight: .semibold))
                    Text(trendText)
                        .font(.system(size: 9))
                }
                .foregroundStyle(panel.trend.color)
            }
        }
    }

    private var trendText: String {
        guard panel.dataPoints.count >= 2,
              let first = panel.dataPoints.first,
              let last = panel.dataPoints.last else { return "" }
        let diff = last.value - first.value
        let sign = diff >= 0 ? "+" : ""
        return "\(sign)\(String(format: abs(diff) < 10 ? "%.1f" : "%.0f", diff))"
    }
}

struct ChartCell: View {
    let panel: PanelData
    let showValue: Bool
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(panel.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if showValue, let lastValue = panel.lastValue {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(lastValue)
                            .font(.headline.monospacedDigit())

                        if let unit = panel.unit ?? panel.fieldName {
                            Text(unit)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Chart {
                ForEach(Array(panel.dataPoints.enumerated()), id: \.offset) { _, point in
                    AreaMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: height)
        }
    }
}

// MARK: - Widget Size Views

struct SmallDashboardView: View {
    let entry: DashboardEntry

    var body: some View {
        if let panel = entry.panels.first {
            switch panel.displayMode {
            case .singleValue:
                VStack(alignment: .leading) {
                    SingleValueCell(panel: panel, compact: false)
                    Spacer()
                }
            case .chart:
                VStack(alignment: .leading, spacing: 4) {
                    Text(panel.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let lastValue = panel.lastValue {
                        Text(lastValue)
                            .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                    }

                    Spacer(minLength: 4)

                    Chart {
                        ForEach(Array(panel.dataPoints.enumerated()), id: \.offset) { _, point in
                            AreaMark(
                                x: .value("T", point.time),
                                y: .value("V", point.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            LineMark(x: .value("T", point.time), y: .value("V", point.value))
                                .foregroundStyle(Color.accentColor)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(maxHeight: 50)
                }
            case .noData:
                VStack {
                    Text(panel.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("—")
                        .font(.title.weight(.medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        } else {
            VStack {
                Image(systemName: "square.grid.2x2")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text(entry.dashboardName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MediumDashboardView: View {
    let entry: DashboardEntry

    var body: some View {
        if entry.panels.isEmpty {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text(entry.dashboardName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if entry.panels.count == 1, let panel = entry.panels.first {
            singlePanel(panel)
        } else {
            multiPanel
        }
    }

    private func singlePanel(_ panel: PanelData) -> some View {
        Group {
            switch panel.displayMode {
            case .chart:
                ChartCell(panel: panel, showValue: true, height: 60)
            case .singleValue:
                SingleValueCell(panel: panel, compact: false)
            case .noData:
                Text(panel.title).foregroundStyle(.secondary)
            }
        }
    }

    private var multiPanel: some View {
        HStack(spacing: 16) {
            ForEach(Array(entry.panels.prefix(3).enumerated()), id: \.offset) { _, panel in
                VStack(alignment: .leading, spacing: 4) {
                    switch panel.displayMode {
                    case .chart:
                        ChartCell(panel: panel, showValue: true, height: 40)
                    case .singleValue:
                        SingleValueCell(panel: panel, compact: true)
                        Spacer(minLength: 0)
                    case .noData:
                        Text(panel.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("—")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct LargeDashboardView: View {
    let entry: DashboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.dashboardName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if entry.panels.isEmpty {
                Spacer()
                Text("No panels")
                    .font(.headline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                let charts = entry.panels.filter { $0.displayMode == .chart }
                let singles = entry.panels.filter { $0.displayMode != .chart }

                // Show charts first
                ForEach(Array(charts.prefix(2).enumerated()), id: \.offset) { _, panel in
                    ChartCell(panel: panel, showValue: true, height: 50)
                }

                // Then single values in a grid row
                if !singles.isEmpty {
                    HStack(spacing: 16) {
                        ForEach(Array(singles.prefix(4).enumerated()), id: \.offset) { _, panel in
                            SingleValueCell(panel: panel, compact: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Widget

struct IoTPanelsWidget: Widget {
    let kind: String = "IoTPanelsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectDashboardIntent.self,
            provider: DashboardTimelineProvider()
        ) { entry in
            IoTPanelsWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("IoT Dashboard")
        .description("Display a dashboard with live data from your IoT panels.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct IoTPanelsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DashboardEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallDashboardView(entry: entry)
                .padding()
        case .systemMedium:
            MediumDashboardView(entry: entry)
                .padding()
        case .systemLarge:
            LargeDashboardView(entry: entry)
                .padding()
        default:
            MediumDashboardView(entry: entry)
                .padding()
        }
    }
}

@main
struct IoTPanelsWidgetBundle: WidgetBundle {
    var body: some Widget {
        IoTPanelsWidget()
    }
}
