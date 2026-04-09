import SwiftUI

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var dashboard: Dashboard

    @State private var showingAddPanel = false
    @State private var editingPanel: DashboardPanel?
    @State private var refreshID = UUID()
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var isWiggling = false
    @State private var draggedPanel: DashboardPanel?
    @State private var exploringPanel: DashboardPanel?
    @State private var exportCSVURL: URL?
    @State private var showingShareSheet = false
    @State private var isExporting = false
    @State private var showingAdaptivePopover = false
    @State private var rearrangeByRow: Bool = true
    @StateObject private var heatmapSelection = HeatmapSelectionState()
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

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
            if isWiggling {
                ToolbarItem(placement: .navigation) {
                    Toggle(isOn: $rearrangeByRow) {
                        Label("Group rows", systemImage: rearrangeByRow ? "rectangle.3.group" : "rectangle.grid.1x2")
                    }
                    .toggleStyle(.button)
                }
            }
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
        #if os(macOS)
        .onChange(of: exploringPanel) { _, panel in
            if let panel {
                openExplorerWindow(panel)
                exploringPanel = nil
            }
        }
        #else
        .fullScreenCover(item: $exploringPanel) { panel in
            ChartExplorerView(panel: panel)
        }
        #endif
        #if os(iOS)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportCSVURL {
                DataShareSheetView(items: [url])
            }
        }
        #else
        .onChange(of: showingShareSheet) { _, newValue in
            if newValue, let url = exportCSVURL {
                MacFileExporter.revealOrExport(url: url)
                showingShareSheet = false
            }
        }
        #endif
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Exporting...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    #if os(macOS)
    private func openExplorerWindow(_ panel: DashboardPanel) {
        openWindow(value: panel.wrappedId)
    }
    #endif

    // MARK: - Normal Mode

    private var normalContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                let panels = dashboard.sortedPanels

                if hasAdaptivePanels(panels) {
                    adaptiveLayoutChip
                }

                if panels.isEmpty {
                    ContentUnavailableView(
                        "No Panels",
                        systemImage: "rectangle.on.rectangle",
                        description: Text("Tap + to add a panel from your saved queries.")
                    )
                    .padding(.top, 60)
                }

                if !panels.isEmpty {
                    PanelFlowLayout {
                        ForEach(panels, id: \.objectID) { panel in
                            PanelCardView(panel: panel)
                                .id("\(panel.objectID)-\(refreshID)")
                                .panelFraction(panel.wrappedWidthSlot.fraction(for: horizontalSizeClass))
                                .panelLineBreakBefore(panel.wrappedLineBreakBefore)
                                .contextMenu {
                                Button {
                                    exploringPanel = panel
                                } label: {
                                    Label("Explore", systemImage: "arrow.up.left.and.arrow.down.right")
                                }

                                Menu("Export") {
                                    Button {
                                        exportPanel(panel, format: .csv)
                                    } label: {
                                        Label("CSV", systemImage: "tablecells")
                                    }
                                    Button {
                                        exportPanel(panel, format: .json)
                                    } label: {
                                        Label("JSON", systemImage: "curlybraces")
                                    }
                                }

                                Button {
                                    editingPanel = panel
                                } label: {
                                    Label("Edit Panel", systemImage: "pencil")
                                }

                                Menu("Display Style") {
                                    let currentStyle = panel.wrappedDisplayStyle
                                    ForEach(PanelDisplayStyle.grouped(), id: \.category) { group in
                                        Section(group.category.displayName) {
                                            ForEach(group.styles) { style in
                                                Button {
                                                    panel.wrappedDisplayStyle = style
                                                    panel.modifiedAt = Date()
                                                    dashboard.modifiedAt = Date()
                                                    try? viewContext.save()
                                                    WidgetHelper.reloadWidgets()
                                                    refreshID = UUID()
                                                } label: {
                                                    if currentStyle == style {
                                                        Label(style.displayName, systemImage: "checkmark")
                                                    } else {
                                                        Label(style.displayName, systemImage: style.icon)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Menu("Layout") {
                                    let allowed = panel.wrappedDisplayStyle.allowedWidthSlots
                                    let current = panel.wrappedWidthSlot
                                    Section("Width") {
                                        ForEach(allowed) { slot in
                                            Button {
                                                panel.wrappedWidthSlot = slot
                                                panel.modifiedAt = Date()
                                                dashboard.modifiedAt = Date()
                                                try? viewContext.save()
                                                refreshID = UUID()
                                            } label: {
                                                if slot == current {
                                                    Label(slot.displayName, systemImage: "checkmark")
                                                } else {
                                                    Text(slot.displayName)
                                                }
                                            }
                                        }
                                    }
                                    Section {
                                        Button {
                                            panel.wrappedLineBreakBefore.toggle()
                                            panel.modifiedAt = Date()
                                            dashboard.modifiedAt = Date()
                                            try? viewContext.save()
                                            refreshID = UUID()
                                        } label: {
                                            if panel.wrappedLineBreakBefore {
                                                Label("Break to new row", systemImage: "checkmark")
                                            } else {
                                                Text("Break to new row")
                                            }
                                        }
                                    }
                                    Section {
                                        Button {
                                            withAnimation { isWiggling = true }
                                        } label: {
                                            Label("Rearrange Panels", systemImage: "arrow.up.arrow.down")
                                        }
                                    }
                                }

                                Button {
                                    duplicatePanel(panel)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
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
                            .fill(Color.platformSecondaryGroupedBackground)
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
        #if os(iOS)
        .refreshable {
            // Give panels a moment to reload, then update the view
            try? await Task.sleep(for: .milliseconds(300))
            refreshID = UUID()
        }
        #endif
    }

    // MARK: - Edit / Rearrange Mode

    @State private var editPanels: [DashboardPanel] = []

    @ViewBuilder
    private var editModeContent: some View {
        Group {
            if rearrangeByRow {
                rowGroupRearrangeContent
            } else {
                individualRearrangeContent
            }
        }
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
        .onAppear {
            editPanels = dashboard.sortedPanels
        }
    }

    // MARK: - Per-panel rearrange (toggle off)

    private var individualRearrangeContent: some View {
        List {
            ForEach(Array(editPanels.enumerated()), id: \.element.objectID) { index, panel in
                VStack(spacing: 4) {
                    if panel.wrappedLineBreakBefore && index > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "return")
                                .font(.caption2)
                            Text("Break to new row")
                                .font(.caption2)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    }
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
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
            .onMove { from, to in
                editPanels.move(fromOffsets: from, toOffset: to)
                savePanelOrder()
            }
        }
    }

    // MARK: - Row-group rearrange (default)

    private var rowGroupRearrangeContent: some View {
        let rows = packPanelsIntoRows(editPanels, horizontalSizeClass: horizontalSizeClass)
        return List {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                VStack(spacing: 4) {
                    if row.first?.wrappedLineBreakBefore == true && rowIndex > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "return")
                                .font(.caption2)
                            Text("Break to new row")
                                .font(.caption2)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    }
                    HStack(spacing: 12) {
                        Button {
                            withAnimation {
                                deleteRow(row)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)

                        PanelFlowLayout {
                            ForEach(row, id: \.objectID) { panel in
                                PanelCardView(panel: panel)
                                    .id("\(panel.objectID)-\(refreshID)")
                                    .panelFraction(panel.wrappedWidthSlot.fraction(for: horizontalSizeClass))
                                    .panelLineBreakBefore(false)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
            .onMove { from, to in
                moveRows(from: from, to: to, currentRows: rows)
            }
        }
    }

    private func deleteRow(_ row: [DashboardPanel]) {
        for panel in row {
            if let idx = editPanels.firstIndex(of: panel) {
                editPanels.remove(at: idx)
            }
            viewContext.delete(panel)
        }
        dashboard.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        refreshID = UUID()
    }

    private func moveRows(from: IndexSet, to: Int, currentRows: [[DashboardPanel]]) {
        var reordered = currentRows
        reordered.move(fromOffsets: from, toOffset: to)

        // Flatten to a single panel sequence in the new order
        let newOrder = reordered.flatMap { $0 }
        editPanels = newOrder

        // Reassign sortOrder
        for (i, panel) in newOrder.enumerated() {
            panel.sortOrder = Int32(i)
        }

        // Preserve the visual grouping the user just chose: force a line
        // break at the start of every row except the first. The first panel
        // of the dashboard ignores its own break flag at render time, so we
        // explicitly clear it for cleanliness.
        for (rowIdx, row) in reordered.enumerated() {
            if let first = row.first {
                first.wrappedLineBreakBefore = (rowIdx > 0)
            }
        }

        dashboard.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        refreshID = UUID()
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

    private func duplicatePanel(_ panel: DashboardPanel) {
        let newPanel = DashboardPanel(context: viewContext)
        newPanel.id = UUID()
        newPanel.title = panel.wrappedTitle
        newPanel.displayStyle = panel.displayStyle
        newPanel.styleConfigJSON = panel.styleConfigJSON
        newPanel.timeRange = panel.timeRange
        newPanel.aggregateWindow = panel.aggregateWindow
        newPanel.aggregateFunction = panel.aggregateFunction
        newPanel.comparisonOffset = panel.comparisonOffset
        newPanel.savedQuery = panel.savedQuery
        newPanel.dashboard = dashboard
        newPanel.sortOrder = Int32(dashboard.sortedPanels.count)
        newPanel.createdAt = Date()
        newPanel.modifiedAt = Date()
        dashboard.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        refreshID = UUID()
    }

    // MARK: - Adaptive Layout Visibility

    private func hasAdaptivePanels(_ panels: [DashboardPanel]) -> Bool {
        panels.contains { $0.wrappedWidthSlot != .full }
    }

    private var adaptiveSizeClassLabel: String {
        horizontalSizeClass == .regular
            ? String(localized: "iPad view")
            : String(localized: "iPhone view")
    }

    private var adaptiveLayoutChip: some View {
        Button {
            showingAdaptivePopover = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.caption2)
                Text("Adaptive layout · \(adaptiveSizeClassLabel)")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .popover(isPresented: $showingAdaptivePopover) {
            adaptiveLayoutExplanation
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }

    private var adaptiveLayoutExplanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adaptive layout")
                .font(.headline)
            Text("Each panel has a width slot. The slot resolves to a different number of panels per row depending on the screen size, so the same dashboard makes good use of both iPhone and iPad.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(PanelWidthSlot.allCases) { slot in
                    HStack(alignment: .top, spacing: 8) {
                        Text(slot.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 90, alignment: .leading)
                        Text(slot.resolutionDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: 360)
    }

    enum ExportFormat { case csv, json }

    private func exportPanel(_ panel: DashboardPanel, format: ExportFormat) {
        isExporting = true
        let points = panel.cachedDataPoints ?? []
        let compPoints = panel.cachedComparisonDataPoints ?? []
        let name = panel.wrappedTitle.isEmpty ? "panel" : panel.wrappedTitle

        Task.detached(priority: .userInitiated) {
            let url: URL?
            switch format {
            case .csv: url = DataExporter.tempCSVFile(name: name, from: points, comparisonPoints: compPoints)
            case .json: url = DataExporter.tempJSONFile(name: name, from: points, comparisonPoints: compPoints)
            }
            await MainActor.run {
                isExporting = false
                if let url {
                    exportCSVURL = url
                    showingShareSheet = true
                }
            }
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
    @State private var widthSlot: PanelWidthSlot = .full
    @State private var lineBreakBefore: Bool = false
    @State private var bandOpacityText = ""
    @State private var newAliasValue = ""
    @State private var newAliasLabel = ""
    @FocusState private var newAliasValueFocused: Bool
    @State private var newStateName = ""
    @State private var newStateColor = "#007AFF"

    // Original values for cancel/restore
    @State private var originalTitle = ""
    @State private var originalStyle: PanelDisplayStyle = .auto
    @State private var originalStyleConfig = StyleConfig.default
    @State private var originalTimeRange: TimeRange = .twoHours
    @State private var originalAggregateWindow: AggregateWindow = .fiveMinutes
    @State private var originalAggregateFunction: AggregateFunction = .mean
    @State private var originalComparisonOffset: ComparisonOffset = .none

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
                    NavigationLink {
                        DisplayStylePickerView(selection: $style)
                    } label: {
                        HStack {
                            Text("Style")
                            Spacer()
                            Label(style.displayName, systemImage: style.icon)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    let allowed = style.allowedWidthSlots
                    Picker("Width", selection: $widthSlot) {
                        ForEach(allowed) { slot in
                            Text("\(slot.displayName) — \(slot.resolutionDescription)").tag(slot)
                        }
                    }
                    Toggle("Break to new row", isOn: $lineBreakBefore)
                } header: {
                    Text("Layout")
                } footer: {
                    Text("Width adapts to screen size. \"Small\" shows 2 panels per row on iPhone and 4 on iPad.")
                }

                if style.supportsGaugeConfig {
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

                if style.supportsHeatmapColor {
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

                if style.supportsBandConfig {
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

                if style.supportsStateConfig {
                    stateAliasSection
                    stateColorSection
                }

                if style.supportsComparison {
                    Section {
                        Picker("Comparison Period", selection: $comparisonOffset) {
                            ForEach(ComparisonOffset.allCases) { offset in
                                Text(offset.displayName).tag(offset)
                            }
                        }
                        if comparisonOffset != .none {
                            Text(comparisonOffset.pickerDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Compare With")
                    }
                }

                if style.supportsThresholds {
                    ThresholdEditorView(thresholds: Binding(
                        get: { styleConfig.thresholds ?? [] },
                        set: { styleConfig.thresholds = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Preview") {
                    PanelCardView(panel: panel)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Edit Panel")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        panel.title = originalTitle
                        panel.wrappedDisplayStyle = originalStyle
                        panel.wrappedStyleConfig = originalStyleConfig
                        panel.effectiveTimeRange = originalTimeRange
                        panel.effectiveAggregateWindow = originalAggregateWindow
                        panel.effectiveAggregateFunction = originalAggregateFunction
                        panel.wrappedComparisonOffset = originalComparisonOffset
                        panel.modifiedAt = Date()
                        try? viewContext.save()
                        dismiss()
                    }
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
                        // Clamp the width slot to a value the (possibly newly chosen)
                        // display style supports.
                        let allowed = style.allowedWidthSlots
                        panel.wrappedWidthSlot = allowed.contains(widthSlot) ? widthSlot : .full
                        panel.wrappedLineBreakBefore = lineBreakBefore
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
                widthSlot = panel.wrappedWidthSlot
                lineBreakBefore = panel.wrappedLineBreakBefore
                if let opacity = styleConfig.bandOpacity { bandOpacityText = String(format: "%.1f", opacity) }

                // Save originals for cancel/restore
                originalTitle = panel.wrappedTitle
                originalStyle = panel.wrappedDisplayStyle
                originalStyleConfig = panel.wrappedStyleConfig
                originalTimeRange = panel.effectiveTimeRange
                originalAggregateWindow = panel.effectiveAggregateWindow
                originalAggregateFunction = panel.effectiveAggregateFunction
                originalComparisonOffset = panel.wrappedComparisonOffset
            }
            .onChange(of: style) {
                panel.wrappedDisplayStyle = style
                // Clamp width slot if the new style doesn't support the current one.
                if !style.allowedWidthSlots.contains(widthSlot) {
                    widthSlot = .full
                }
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
        .macSheet()
    }

    // MARK: - State Timeline Config

    private var sortedAliases: [StateAlias] {
        (styleConfig.stateAliases ?? []).sorted { $0.value < $1.value }
    }

    private var sortedAliasIndices: [(offset: Int, alias: StateAlias)] {
        guard let aliases = styleConfig.stateAliases else { return [] }
        return aliases.enumerated()
            .sorted { $0.element.value < $1.element.value }
            .map { (offset: $0.offset, alias: $0.element) }
    }

    private var stateAliasSection: some View {
        Section {
            ForEach(sortedAliasIndices, id: \.alias.value) { item in
                HStack {
                    Text("≥")
                        .foregroundStyle(.secondary)
                    TextField("0", text: Binding(
                        get: { String(format: "%.0f", styleConfig.stateAliases?[item.offset].value ?? 0) },
                        set: { if let val = Double($0) { styleConfig.stateAliases?[item.offset].value = val } }
                    ))
                    .keyboardType(.decimalPad)
                    .frame(width: 50)
                    TextField("Label", text: Binding(
                        get: { styleConfig.stateAliases?[item.offset].label ?? "" },
                        set: { styleConfig.stateAliases?[item.offset].label = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
            }
            .onDelete { offsets in
                let toRemove = offsets.map { sortedAliasIndices[$0].offset }
                for index in toRemove.sorted().reversed() {
                    styleConfig.stateAliases?.remove(at: index)
                }
                if styleConfig.stateAliases?.isEmpty == true { styleConfig.stateAliases = nil }
            }

            HStack {
                Text("≥")
                    .foregroundStyle(.secondary)
                TextField("0", text: $newAliasValue)
                    .keyboardType(.decimalPad)
                    .frame(width: 50)
                    .focused($newAliasValueFocused)
                TextField("Label (e.g. Calm)", text: $newAliasLabel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    guard let val = Double(newAliasValue), !newAliasLabel.isEmpty else { return }
                    if styleConfig.stateAliases == nil { styleConfig.stateAliases = [] }
                    styleConfig.stateAliases?.removeAll { $0.value == val }
                    styleConfig.stateAliases?.append(StateAlias(value: val, label: newAliasLabel))
                    newAliasValue = ""
                    newAliasLabel = ""
                    newAliasValueFocused = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(Double(newAliasValue) == nil || newAliasLabel.isEmpty)
            }
        } header: {
            Text("Value Aliases")
        } footer: {
            Text("Map numeric value ranges to state labels. \"≥ 20 Windy\" means values from 20 upward show as \"Windy\". Swipe to delete.")
        }
    }

    private var stateColorSection: some View {
        Section {
            ForEach(Array((styleConfig.stateColors ?? []).enumerated()), id: \.element.state) { index, entry in
                HStack {
                    stateColorPicker(currentHex: entry.colorHex) { hex in
                        styleConfig.stateColors?[index].colorHex = hex
                    }
                    Text(entry.state)
                }
            }
            .onDelete { offsets in
                let entries = styleConfig.stateColors ?? []
                let toRemove = offsets.map { entries[$0].state }
                styleConfig.stateColors?.removeAll { toRemove.contains($0.state) }
                if styleConfig.stateColors?.isEmpty == true { styleConfig.stateColors = nil }
            }

            // Quick-add from alias labels
            let existingStates = Set((styleConfig.stateColors ?? []).map(\.state))
            let suggestions = sortedAliases.map(\.label).filter { !existingStates.contains($0) }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { label in
                            Button(label) {
                                if styleConfig.stateColors == nil { styleConfig.stateColors = [] }
                                styleConfig.stateColors?.append(StateColorEntry(state: label, colorHex: newStateColor))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            HStack {
                stateColorPicker(currentHex: newStateColor) { hex in
                    newStateColor = hex
                }
                TextField("State name", text: $newStateName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    guard !newStateName.isEmpty else { return }
                    if styleConfig.stateColors == nil { styleConfig.stateColors = [] }
                    styleConfig.stateColors?.removeAll { $0.state == newStateName }
                    styleConfig.stateColors?.append(StateColorEntry(state: newStateName, colorHex: newStateColor))
                    newStateName = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newStateName.isEmpty)
            }
        } header: {
            Text("State Colors")
        } footer: {
            Text("Map state values to colors. Unmapped states use automatic colors. Swipe to delete.")
        }
    }

    private func stateColorPicker(currentHex: String, onSelect: @escaping (String) -> Void) -> some View {
        let binding = Binding<String>(
            get: { currentHex },
            set: { onSelect($0) }
        )
        return Picker("", selection: binding) {
            ForEach(StateColorResolver.palette, id: \.hex) { entry in
                Label(entry.name, systemImage: "circle.fill")
                    .tint(Color(hex: entry.hex))
                    .foregroundStyle(Color(hex: entry.hex))
                    .tag(entry.hex)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(Color(hex: currentHex))
        .fixedSize()
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
        .inlineNavigationTitle()
    }
}
