import SwiftUI

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var dashboard: Dashboard

    @State private var showingAddPanel = false
    @State private var editingPanel: DashboardPanel?
    @State private var isEditMode = false
    @State private var refreshID = UUID()

    var body: some View {
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
                } else {
                    ForEach(Array(panels.enumerated()), id: \.element.objectID) { index, panel in
                        PanelCardView(panel: panel)
                            .id("\(panel.objectID)-\(refreshID)")
                            .contextMenu {
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

                                if index > 0 {
                                    Button {
                                        movePanel(panel, direction: -1)
                                    } label: {
                                        Label("Move Up", systemImage: "arrow.up")
                                    }
                                }

                                if index < panels.count - 1 {
                                    Button {
                                        movePanel(panel, direction: 1)
                                    } label: {
                                        Label("Move Down", systemImage: "arrow.down")
                                    }
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
            .padding()
        }
        .refreshable {
            refreshID = UUID()
        }
        .navigationTitle(dashboard.wrappedName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddPanel = true }) {
                    Label("Add Panel", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPanel, onDismiss: { refreshID = UUID() }) {
            AddPanelView(dashboard: dashboard)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $editingPanel, onDismiss: { refreshID = UUID() }) { panel in
            EditPanelView(panel: panel)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    private func movePanel(_ panel: DashboardPanel, direction: Int) {
        var panels = dashboard.sortedPanels
        guard let idx = panels.firstIndex(of: panel) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0, newIdx < panels.count else { return }

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Panel title", text: $title)
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
            }
            .onChange(of: style) {
                panel.wrappedDisplayStyle = style
            }
            .onChange(of: styleConfig) {
                panel.wrappedStyleConfig = styleConfig
            }
        }
    }
}
