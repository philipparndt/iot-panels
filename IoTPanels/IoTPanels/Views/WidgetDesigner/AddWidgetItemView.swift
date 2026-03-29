import SwiftUI

struct AddWidgetItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let design: WidgetDesign

    @FetchRequest private var dataSources: FetchedResults<DataSource>

    init(design: WidgetDesign) {
        self.design = design
        let predicate: NSPredicate
        if let home = design.home {
            predicate = NSPredicate(format: "home == %@", home)
        } else {
            predicate = NSPredicate(format: "home == nil")
        }
        _dataSources = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \DataSource.name, ascending: true)],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(Array(dataSources.enumerated()), id: \.element.objectID) { _, ds in
                    let queries = fetchQueries(for: ds)
                    if !queries.isEmpty {
                        Section(ds.wrappedName) {
                            ForEach(Array(queries.enumerated()), id: \.element.objectID) { _, query in
                                Button {
                                    addItem(query: query)
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
            .navigationTitle("Add Item")
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
        "\(query.wrappedMeasurement) · \(query.wrappedFields.joined(separator: ", "))"
    }

    private func addItem(query: SavedQuery) {
        let item = WidgetDesignItem(context: viewContext)
        item.id = UUID()
        item.title = query.wrappedName
        item.displayStyle = PanelDisplayStyle.chart.rawValue
        item.colorHex = SeriesColors.color(at: design.sortedItems.count)
        item.sortOrder = Int32(design.sortedItems.count)
        item.savedQuery = query
        item.widgetDesign = design
        item.createdAt = Date()
        item.modifiedAt = Date()

        design.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        dismiss()
    }
}
