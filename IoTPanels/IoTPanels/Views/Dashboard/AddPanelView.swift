import SwiftUI

struct AddPanelView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dashboard: Dashboard

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DataSource.name, ascending: true)],
        animation: .default
    )
    private var dataSources: FetchedResults<DataSource>

    @State private var panelTitle = ""
    @State private var selectedStyle: PanelDisplayStyle = .auto

    var body: some View {
        NavigationStack {
            Form {
                Section("Panel Title") {
                    TextField("Title (optional, defaults to query name)", text: $panelTitle)
                }

                Section("Display Style") {
                    Picker("Style", selection: $selectedStyle) {
                        ForEach(PanelDisplayStyle.allCases) { style in
                            Label(style.displayName, systemImage: style.icon)
                                .tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                }

                ForEach(Array(dataSources.enumerated()), id: \.element.objectID) { _, ds in
                    let queries = fetchQueries(for: ds)
                    if !queries.isEmpty {
                        Section(header: HStack {
                            Text(ds.wrappedName)
                            Spacer()
                            Text(ds.wrappedBackendType.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }) {
                            ForEach(Array(queries.enumerated()), id: \.element.objectID) { _, query in
                                Button {
                                    addPanel(query: query)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(query.wrappedName)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(querySummary(query))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                if dataSources.allSatisfy({ fetchQueries(for: $0).isEmpty }) {
                    ContentUnavailableView(
                        "No Saved Queries",
                        systemImage: "magnifyingglass",
                        description: Text("Create queries in the Data Sources tab first.")
                    )
                }
            }
            .navigationTitle("Add Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func fetchQueries(for dataSource: DataSource) -> [SavedQuery] {
        let set = dataSource.savedQueries as? Set<SavedQuery> ?? []
        return set.sorted { $0.wrappedName < $1.wrappedName }
    }

    private func querySummary(_ query: SavedQuery) -> String {
        let fields = query.wrappedFields
        let fieldText = fields.isEmpty ? "" : fields.joined(separator: ", ")
        return "\(query.wrappedMeasurement) · \(fieldText)"
    }

    private func addPanel(query: SavedQuery) {
        let panel = DashboardPanel(context: viewContext)
        panel.id = UUID()
        panel.title = panelTitle.isEmpty ? query.wrappedName : panelTitle
        panel.wrappedDisplayStyle = selectedStyle
        panel.savedQuery = query
        panel.dashboard = dashboard
        panel.sortOrder = Int32(dashboard.sortedPanels.count)
        panel.createdAt = Date()
        panel.modifiedAt = Date()

        dashboard.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        dismiss()
    }
}
