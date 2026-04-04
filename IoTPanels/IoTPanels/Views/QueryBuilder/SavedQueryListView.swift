import SwiftUI

struct SavedQueryListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let dataSource: DataSource

    @FetchRequest private var savedQueries: FetchedResults<SavedQuery>

    @State private var showingQueryBuilder = false
    @State private var showingManualEditor = false
    @State private var selectedQuery: SavedQuery?

    init(dataSource: DataSource) {
        self.dataSource = dataSource
        _savedQueries = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \SavedQuery.name, ascending: true)],
            predicate: NSPredicate(format: "dataSource == %@", dataSource),
            animation: .default
        )
    }

    var body: some View {
        List {
            if savedQueries.isEmpty {
                ContentUnavailableView(
                    "No Queries",
                    systemImage: "magnifyingglass",
                    description: Text("Tap + to create your first query.")
                )
            } else {
                ForEach(Array(savedQueries.enumerated()), id: \.element.objectID) { _, query in
                    NavigationLink {
                        SavedQueryDetailView(dataSource: dataSource, savedQuery: query)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(query.wrappedName)
                                .font(.headline)
                            Text(querySummary(query))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteQueries)
            }
        }
        .navigationTitle("Queries")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isInfluxBackend || isPrometheusBackend {
                    Menu {
                        Button {
                            showingQueryBuilder = true
                        } label: {
                            Label("Query Builder", systemImage: "list.bullet.rectangle")
                        }
                        Button {
                            showingManualEditor = true
                        } label: {
                            Label("Manual Query", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                } else {
                    Button(action: { showingQueryBuilder = true }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingQueryBuilder) {
            queryBuilderSheet(existingQuery: nil)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingManualEditor) {
            ManualQueryEditorView(dataSource: dataSource, existingQuery: nil)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    private var isInfluxBackend: Bool {
        let bt = dataSource.wrappedBackendType
        return bt == .influxDB1 || bt == .influxDB2 || bt == .influxDB3
    }

    private var isPrometheusBackend: Bool {
        dataSource.wrappedBackendType == .prometheus
    }

    private func querySummary(_ query: SavedQuery) -> String {
        if query.wrappedIsRawQuery {
            let preview = query.wrappedRawQuery.prefix(60)
            return "Manual · \(preview)\(query.wrappedRawQuery.count > 60 ? "..." : "")"
        }
        let fields = query.wrappedFields
        let fieldText = fields.isEmpty ? "" : fields.joined(separator: ", ")
        return "\(query.wrappedMeasurement) · \(fieldText) · \(query.wrappedTimeRange.displayName)"
    }

    @ViewBuilder
    private func queryBuilderSheet(existingQuery: SavedQuery?) -> some View {
        if dataSource.wrappedBackendType == .mqtt {
            MQTTQueryBuilderView(dataSource: dataSource, existingQuery: existingQuery)
        } else if dataSource.wrappedBackendType == .prometheus {
            PrometheusQueryBuilderView(dataSource: dataSource, existingQuery: existingQuery)
        } else {
            QueryBuilderView(dataSource: dataSource, existingQuery: existingQuery)
        }
    }

    private func deleteQueries(offsets: IndexSet) {
        withAnimation {
            offsets.map { savedQueries[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}
