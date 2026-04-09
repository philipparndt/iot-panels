import SwiftUI
import CoreData

struct AddPanelView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dashboard: Dashboard

    @FetchRequest private var dataSources: FetchedResults<DataSource>

    init(dashboard: Dashboard) {
        self.dashboard = dashboard
        let predicate: NSPredicate
        if let home = dashboard.home {
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

    @State private var panelTitle = ""
    @State private var selectedStyle: PanelDisplayStyle = .auto
    @State private var selectedDataSource: DataSource?
    @State private var queryBuilderDataSource: DataSource?

    var body: some View {
        NavigationStack {
            Form {
                Section("Panel Title") {
                    TextField("Title (optional, defaults to query name)", text: $panelTitle)
                }

                Section("Display Style") {
                    NavigationLink {
                        DisplayStylePickerView(selection: $selectedStyle)
                    } label: {
                        HStack {
                            Text("Style")
                            Spacer()
                            Label(selectedStyle.displayName, systemImage: selectedStyle.icon)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let ds = selectedDataSource {
                    querySection(for: ds)
                } else {
                    dataSourcePickerSection
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Add Panel")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $queryBuilderDataSource) { ds in
                queryBuilderSheet(for: ds)
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                // Auto-select if only one data source exists.
                if selectedDataSource == nil, dataSources.count == 1 {
                    selectedDataSource = dataSources.first
                }
            }
            .onChange(of: dataSources.count) { _, newValue in
                if selectedDataSource == nil, newValue == 1 {
                    selectedDataSource = dataSources.first
                }
            }
        }
        .macSheet()
    }

    // MARK: - Data Source Picker

    @ViewBuilder
    private var dataSourcePickerSection: some View {
        if dataSources.isEmpty {
            Section {
                ContentUnavailableView(
                    "No Data Sources",
                    systemImage: "server.rack",
                    description: Text("Add a data source first.")
                )
            }
        } else {
            Section("Data Source") {
                ForEach(dataSources, id: \.objectID) { ds in
                    Button {
                        selectedDataSource = ds
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ds.wrappedName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(ds.wrappedBackendType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Query Picker

    @ViewBuilder
    private func querySection(for ds: DataSource) -> some View {
        let queries = fetchQueries(for: ds)
        let canSwitchDataSource = dataSources.count > 1

        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ds.wrappedName)
                        .font(.headline)
                    Text(ds.wrappedBackendType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if canSwitchDataSource {
                    Button("Change") {
                        selectedDataSource = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        } header: {
            Text("Data Source")
        }

        Section("Query") {
            if queries.isEmpty {
                Text("No saved queries")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(queries, id: \.objectID) { query in
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

            Button {
                queryBuilderDataSource = ds
            } label: {
                Label("New Query", systemImage: "magnifyingglass.circle")
            }
        }
    }

    @ViewBuilder
    private func queryBuilderSheet(for dataSource: DataSource) -> some View {
        if dataSource.wrappedBackendType == .mqtt {
            MQTTQueryBuilderView(dataSource: dataSource, existingQuery: nil, defaultName: panelTitle)
        } else {
            QueryBuilderView(dataSource: dataSource, existingQuery: nil, defaultName: panelTitle)
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
