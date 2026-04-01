import SwiftUI

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var dashboard: Dashboard

    @State private var showingAddPanel = false
    @State private var editingPanel: DashboardPanel?
    @State private var refreshID = UUID()
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var isWiggling = false
    @State private var draggedPanel: DashboardPanel?
    @State private var exploringPanel: DashboardPanel?
    @StateObject private var heatmapSelection = HeatmapSelectionState()

    var body: some View {
        Group {
            if isWiggling {
                editModeContent
            } else {
                normalContent
            }
        }
        .environmentObject(heatmapSelection)
        .navigationTitle(dashboard.wrappedName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isWiggling {
                    Button("Done") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isWiggling = false
                        }
                    }
                    .fontWeight(.semibold)
                } else {
                    Menu {
                        Button(action: { showingAddPanel = true }) {
                            Label("Add Panel", systemImage: "plus")
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isWiggling = true
                            }
                        } label: {
                            Label("Rearrange Panels", systemImage: "arrow.up.arrow.down")
                        }
                        Button {
                            renameText = dashboard.wrappedName
                            showingRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                    } label: {
                        Label("Menu", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Rename Dashboard", isPresented: $showingRename) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                dashboard.name = renameText
                dashboard.modifiedAt = Date()
                try? viewContext.save()
            }
        }
        .sheet(isPresented: $showingAddPanel, onDismiss: { refreshID = UUID() }) {
            AddPanelView(dashboard: dashboard)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $editingPanel, onDismiss: { refreshID = UUID() }) { panel in
            EditPanelView(panel: panel)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(heatmapSelection)
        }
        .fullScreenCover(item: $exploringPanel) { panel in
            ChartExplorerView(panel: panel)
        }
    }

    // MARK: - Normal Mode

    private var normalContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let panels = dashboard.sortedPanels
                if panels.isEmpty {
                    ContentUnavailableView(
                        "No Panels",
                        systemImage: "rectangle.on.rectangle",
                        description: Text("Tap + to add a panel from your saved queries.")
                    )
                    .padding(.top, 60)
                }

                if !panels.isEmpty {
                    ForEach(panels, id: \.objectID) { panel in
                        PanelCardView(panel: panel)
                            .id("\(panel.objectID)-\(refreshID)")
                            .contextMenu {
                                Button {
                                    exploringPanel = panel
                                } label: {
                                    Label("Explore", systemImage: "arrow.up.left.and.arrow.down.right")
                                }

                                Button {
                                    editingPanel = panel
                                } label: {
                                    Label("Edit Panel", systemImage: "pencil")
                                }

                                Menu("Display Style") {
                                    ForEach(PanelDisplayStyle.allCases) { style in
                                        Button {
                                            panel.wrappedDisplayStyle = style
                                            panel.modifiedAt = Date()
                                            dashboard.modifiedAt = Date()
                                            try? viewContext.save()
                                            WidgetHelper.reloadWidgets()
                                            refreshID = UUID()
                                        } label: {
                                            Label(style.displayName, systemImage: style.icon)
                                            if panel.wrappedDisplayStyle == style {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }

                                Divider()

                                Button {
                                    withAnimation { isWiggling = true }
                                } label: {
                                    Label("Rearrange Panels", systemImage: "arrow.up.arrow.down")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    withAnimation {
                                        viewContext.delete(panel)
                                        dashboard.modifiedAt = Date()
                                        try? viewContext.save()
                                        WidgetHelper.reloadWidgets()
                                        refreshID = UUID()
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }

                // Add panel card
                Button {
                    showingAddPanel = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("Add Panel")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                            .foregroundStyle(.quaternary)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .refreshable {
            // Give panels a moment to reload, then update the view
            try? await Task.sleep(for: .milliseconds(300))
            refreshID = UUID()
        }
    }

    // MARK: - Edit / Rearrange Mode

    @State private var editPanels: [DashboardPanel] = []

    private var editModeContent: some View {
        List {
            ForEach(editPanels, id: \.objectID) { panel in
                HStack(spacing: 12) {
                    Button {
                        withAnimation {
                            if let idx = editPanels.firstIndex(of: panel) {
                                editPanels.remove(at: idx)
                            }
                            viewContext.delete(panel)
                            dashboard.modifiedAt = Date()
                            try? viewContext.save()
                            WidgetHelper.reloadWidgets()
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)

                    PanelCardView(panel: panel)
                        .id("\(panel.objectID)-\(refreshID)")
                        .allowsHitTesting(false)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
            .onMove { from, to in
                editPanels.move(fromOffsets: from, toOffset: to)
                savePanelOrder()
            }
        }
        .environment(\.editMode, .constant(.active))
        .onAppear {
            editPanels = dashboard.sortedPanels
        }
    }

    private func savePanelOrder() {
        for (i, panel) in editPanels.enumerated() {
            panel.sortOrder = Int32(i)
        }
        dashboard.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        refreshID = UUID()
    }

    private func movePanel(_ panel: DashboardPanel, direction: Int) {
        var panels = dashboard.sortedPanels
        guard let idx = panels.firstIndex(of: panel) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0, newIdx < panels.count else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            panels.swapAt(idx, newIdx)
            for (i, p) in panels.enumerated() {
                p.sortOrder = Int32(i)
            }
            dashboard.modifiedAt = Date()
            try? viewContext.save()
            WidgetHelper.reloadWidgets()
            refreshID = UUID()
        }
    }

}

// MARK: - Edit Panel Sheet

struct EditPanelView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var panel: DashboardPanel

    @State private var title: String = ""
    @State private var style: PanelDisplayStyle = .auto
    @State private var styleConfig = StyleConfig.default
    @State private var gaugeMinText = ""
    @State private var gaugeMaxText = ""
    @State private var timeRange: TimeRange = .twoHours
    @State private var aggregateWindow: AggregateWindow = .fiveMinutes
    @State private var aggregateFunction: AggregateFunction = .mean
    @State private var comparisonOffset: ComparisonOffset = .none
    @State private var bandOpacityText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Panel title", text: $title)
                }

                Section("Data") {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .onChange(of: timeRange) {
                        let allowed = timeRange.allowedWindows
                        if !allowed.contains(aggregateWindow) {
                            aggregateWindow = timeRange.minimumWindow
                        }
                    }
                    Picker("Aggregation", selection: $aggregateWindow) {
                        ForEach(timeRange.allowedWindows) { window in
                            Text(window.displayName).tag(window)
                        }
                    }
                    Picker("Function", selection: $aggregateFunction) {
                        ForEach(AggregateFunction.allCases) { fn in
                            Text(fn.displayName).tag(fn)
                        }
                    }

                    if let query = panel.savedQuery, let dataSource = query.dataSource {
                        NavigationLink {
                            SavedQueryDetailView(dataSource: dataSource, savedQuery: query)
                        } label: {
                            HStack {
                                Text("Query")
                                Spacer()
                                Text(query.wrappedName)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        ChangeQueryView(panel: panel)
                    } label: {
                        Text("Change Query")
                    }
                }

                Section("Display Style") {
                    ForEach(PanelDisplayStyle.allCases) { s in
                        Button {
                            style = s
                        } label: {
                            HStack {
                                Label(s.displayName, systemImage: s.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if style == s {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                if style == .gauge {
                    Section {
                        HStack {
                            Text("Min")
                                .frame(width: 40)
                            TextField("Auto", text: $gaugeMinText)
                                .keyboardType(.decimalPad)
                                .onChange(of: gaugeMinText) {
                                    styleConfig.gaugeMin = Double(gaugeMinText)
                                }
                        }
                        HStack {
                            Text("Max")
                                .frame(width: 40)
                            TextField("Auto", text: $gaugeMaxText)
                                .keyboardType(.decimalPad)
                                .onChange(of: gaugeMaxText) {
                                    styleConfig.gaugeMax = Double(gaugeMaxText)
                                }
                        }
                    } header: {
                        Text("Gauge Range")
                    } footer: {
                        Text("Leave empty for auto range based on data.")
                    }

                    Section("Gauge Color Scheme") {
                        ForEach(GaugeColorScheme.allCases) { scheme in
                            Button {
                                styleConfig.gaugeColorScheme = scheme.rawValue
                            } label: {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(colors: scheme.colors, startPoint: .leading, endPoint: .trailing))
                                        .frame(width: 40, height: 10)
                                    Text(scheme.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if styleConfig.resolvedGaugeColorScheme == scheme {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                if style == .calendarHeatmap || style == .calendarHeatmapDense {
                    Section("Heatmap Color") {
                        ForEach(HeatmapColor.allCases) { color in
                            Button {
                                styleConfig.heatmapColor = color.rawValue
                            } label: {
                                HStack(spacing: 8) {
                                    HeatmapSwatchView(color: color)
                                        .frame(width: 60, height: 14)
                                    Text(color.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if styleConfig.resolvedHeatmapColor == color {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                if style == .bandChart {
                    Section {
                        HStack {
                            Text("Band Opacity")
                            Spacer()
                            TextField("0.2", text: $bandOpacityText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .onChange(of: bandOpacityText) {
                                    styleConfig.bandOpacity = Double(bandOpacityText)
                                }
                        }
                    } header: {
                        Text("Band Chart Style")
                    } footer: {
                        Text("Opacity of the min/max band fill (0.0–1.0). Default is 0.2.")
                    }
                }

                if style.isLineBased {
                    Section("Compare With") {
                        Picker("Comparison Period", selection: $comparisonOffset) {
                            ForEach(ComparisonOffset.allCases) { offset in
                                Text(offset.displayName).tag(offset)
                            }
                        }
                    }
                }

                Section("Preview") {
                    PanelCardView(panel: panel)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Edit Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        panel.title = title
                        panel.wrappedDisplayStyle = style
                        panel.wrappedStyleConfig = styleConfig
                        panel.effectiveTimeRange = timeRange
                        panel.effectiveAggregateWindow = aggregateWindow
                        panel.effectiveAggregateFunction = aggregateFunction
                        panel.wrappedComparisonOffset = comparisonOffset
                        panel.modifiedAt = Date()
                        try? viewContext.save()
                        WidgetHelper.reloadWidgets()
                        dismiss()
                    }
                }
            }
            .onAppear {
                title = panel.wrappedTitle
                style = panel.wrappedDisplayStyle
                styleConfig = panel.wrappedStyleConfig
                if let min = styleConfig.gaugeMin { gaugeMinText = String(format: "%.1f", min) }
                if let max = styleConfig.gaugeMax { gaugeMaxText = String(format: "%.1f", max) }
                timeRange = panel.effectiveTimeRange
                aggregateWindow = panel.effectiveAggregateWindow
                aggregateFunction = panel.effectiveAggregateFunction
                comparisonOffset = panel.wrappedComparisonOffset
                if let opacity = styleConfig.bandOpacity { bandOpacityText = String(format: "%.1f", opacity) }
            }
            .onChange(of: style) {
                panel.wrappedDisplayStyle = style
                // Auto-select minimum aggregate window for band chart
                if style == .bandChart && aggregateWindow == .none {
                    aggregateWindow = timeRange.minimumWindow
                }
            }
            .onChange(of: styleConfig) {
                panel.wrappedStyleConfig = styleConfig
            }
            .onChange(of: comparisonOffset) {
                panel.wrappedComparisonOffset = comparisonOffset
            }
            .onChange(of: timeRange) {
                panel.effectiveTimeRange = timeRange
            }
            .onChange(of: aggregateWindow) {
                panel.effectiveAggregateWindow = aggregateWindow
            }
            .onChange(of: aggregateFunction) {
                panel.effectiveAggregateFunction = aggregateFunction
            }
        }
    }
}

struct HeatmapSwatchView: View {
    let color: HeatmapColor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                let dark = colorScheme == .dark
                let colors = dark ? color.swatchColorsDark : color.swatchColors
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[i])
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Change Query

struct ChangeQueryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var panel: DashboardPanel

    private var dataSources: [DataSource] {
        guard let home = panel.dashboard?.home else { return [] }
        let set = home.dataSources as? Set<DataSource> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    var body: some View {
        List {
            ForEach(dataSources, id: \.objectID) { ds in
                let queries = (ds.savedQueries as? Set<SavedQuery> ?? []).sorted { $0.wrappedName < $1.wrappedName }
                Section(ds.wrappedName) {
                    ForEach(queries, id: \.objectID) { query in
                        Button {
                            panel.savedQuery = query
                            panel.modifiedAt = Date()
                            try? viewContext.save()
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(query.wrappedName)
                                        .foregroundStyle(.primary)
                                    Text("\(query.wrappedMeasurement) · \(query.wrappedFields.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if query == panel.savedQuery {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Change Query")
        .navigationBarTitleDisplayMode(.inline)
    }
}
