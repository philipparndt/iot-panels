import SwiftUI

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var dashboard: Dashboard

    @State private var showingAddPanel = false
    @State private var editingPanel: DashboardPanel?
    @State private var isEditMode = false

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
                                            try? viewContext.save()
                                            WidgetHelper.reloadWidgets()
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
                                        try? viewContext.save()
                                        WidgetHelper.reloadWidgets()
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
        .navigationTitle(dashboard.wrappedName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddPanel = true }) {
                    Label("Add Panel", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPanel) {
            AddPanelView(dashboard: dashboard)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $editingPanel) { panel in
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
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
    }
}

// MARK: - Edit Panel Sheet

struct EditPanelView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var panel: DashboardPanel

    @State private var title: String = ""
    @State private var style: PanelDisplayStyle = .auto

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
            }
            .onChange(of: style) {
                panel.wrappedDisplayStyle = style
            }
        }
    }
}
