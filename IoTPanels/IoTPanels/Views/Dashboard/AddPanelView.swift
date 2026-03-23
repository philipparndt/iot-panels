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

    @State private var selectedDataSource: DataSource?
    @State private var panelTitle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Panel Title") {
                    TextField("Title (optional)", text: $panelTitle)
                }

                ForEach(Array(dataSources.enumerated()), id: \.element.objectID) { _, ds in
                    let queries = fetchQueries(for: ds)
                    if !queries.isEmpty {
                        Section(ds.wrappedName) {
                            ForEach(Array(queries.enumerated()), id: \.element.objectID) { _, query in
                                Button {
                                    addPanel(query: query, dataSource: ds)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(query.wrappedName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(querySummary(query))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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

    private func addPanel(query: SavedQuery, dataSource: DataSource) {
        let panel = DashboardPanel(context: viewContext)
        panel.id = UUID()
        panel.title = panelTitle.isEmpty ? query.wrappedName : panelTitle
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
