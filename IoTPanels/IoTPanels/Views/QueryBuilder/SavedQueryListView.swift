import SwiftUI

struct SavedQueryListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let dataSource: DataSource

    @FetchRequest private var savedQueries: FetchedResults<SavedQuery>

    @State private var showingQueryBuilder = false
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
                Button(action: { showingQueryBuilder = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingQueryBuilder) {
            QueryBuilderView(dataSource: dataSource, existingQuery: nil)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    private func querySummary(_ query: SavedQuery) -> String {
        let fields = query.wrappedFields
        let fieldText = fields.isEmpty ? "" : fields.joined(separator: ", ")
        return "\(query.wrappedMeasurement) · \(fieldText) · \(query.wrappedTimeRange.displayName)"
    }

    private func deleteQueries(offsets: IndexSet) {
        withAnimation {
            offsets.map { savedQueries[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}
