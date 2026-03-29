import SwiftUI

struct DashboardListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(NavigationState.self) private var navigationState

    let home: Home?

    @FetchRequest private var dashboards: FetchedResults<Dashboard>
    @FetchRequest private var dataSources: FetchedResults<DataSource>

    @State private var showingAdd = false
    @State private var showingResetDemo = false

    init(home: Home?) {
        self.home = home
        let predicate: NSPredicate
        if let home {
            predicate = NSPredicate(format: "home == %@", home)
        } else {
            predicate = NSPredicate(format: "home == nil")
        }
        _dashboards = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Dashboard.name, ascending: true)],
            predicate: predicate,
            animation: .default
        )
        _dataSources = FetchRequest(
            sortDescriptors: [],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        List {
            if dataSources.isEmpty && dashboards.isEmpty {
                ContentUnavailableView {
                    Label("Welcome to IoT Panels", systemImage: "house")
                } description: {
                    Text("Get started by connecting a data source, or explore with a pre-built demo home.")
                } actions: {
                    Button("Try Demo Home") {
                        let demo = HomeManager.demoHome(context: viewContext)
                        if demo.dataSources?.count == 0 {
                            DemoSetup.install(context: viewContext)
                        }
                        navigationState.selectedHome = demo
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Add Data Source") {
                        navigationState.showAddDataSource = true
                        navigationState.selectedTab = .dataSources
                    }
                    .buttonStyle(.bordered)
                }
            } else if dataSources.isEmpty {
                ContentUnavailableView {
                    Label("No Data Sources", systemImage: "server.rack")
                } description: {
                    Text("Connect a data source first to start building dashboards.")
                } actions: {
                    Button("Add Data Source") {
                        navigationState.showAddDataSource = true
                        navigationState.selectedTab = .dataSources
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if dashboards.isEmpty {
                ContentUnavailableView(
                    "No Dashboards",
                    systemImage: "square.grid.2x2",
                    description: Text("Tap + to create your first dashboard.")
                )
            } else {
                ForEach(Array(dashboards.enumerated()), id: \.element.objectID) { _, dashboard in
                    NavigationLink {
                        DashboardView(dashboard: dashboard)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(dashboard.wrappedName)
                                .font(.headline)
                            Text("\(dashboard.sortedPanels.count) panels")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteDashboards)
            }
        }
        .navigationTitle("Dashboards")
        .toolbar {
            if navigationState.selectedHome?.isDemo == true {
                ToolbarItem(placement: .navigation) {
                    Button {
                        showingResetDemo = true
                    } label: {
                        Label("Reset Demo", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAdd = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .alert("Reset Demo?", isPresented: $showingResetDemo) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                DemoSetup.reset(context: viewContext)
            }
        } message: {
            Text("This will delete all demo dashboards, data sources, and widgets, then recreate them.")
        }
        .alert("New Dashboard", isPresented: $showingAdd) {
            DashboardNameAlert { name in
                createDashboard(name: name)
            }
        }
    }

    private func createDashboard(name: String) {
        let dashboard = Dashboard(context: viewContext)
        dashboard.id = UUID()
        dashboard.name = name
        dashboard.home = navigationState.selectedHome
        dashboard.createdAt = Date()
        dashboard.modifiedAt = Date()
        try? viewContext.save()
    }

    private func deleteDashboards(offsets: IndexSet) {
        withAnimation {
            offsets.map { dashboards[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

struct DashboardNameAlert: View {
    let onSave: (String) -> Void
    @State private var name = ""

    var body: some View {
        TextField("Dashboard name", text: $name)
        Button("Cancel", role: .cancel) {}
        Button("Create") {
            onSave(name)
        }
        .disabled(name.isEmpty)
    }
}
