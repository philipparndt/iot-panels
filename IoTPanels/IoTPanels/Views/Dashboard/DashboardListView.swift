import SwiftUI

struct DashboardListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(NavigationState.self) private var navigationState

    let home: Home?

    @FetchRequest private var dashboards: FetchedResults<Dashboard>
    @FetchRequest private var dataSources: FetchedResults<DataSource>

    @State private var showingAdd = false
    @State private var showingResetDemo = false
    @State private var showingRenameHome = false
    @State private var showingDeleteHome = false
    @State private var showingNewHome = false
    @State private var showingIconPicker = false
    @State private var homeRenameText = ""

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
            ToolbarItem(placement: .navigation) {
                Menu {
                    Button {
                        homeRenameText = home?.wrappedName ?? ""
                        showingRenameHome = true
                    } label: {
                        Label("Rename Home", systemImage: "pencil")
                    }

                    Button {
                        showingIconPicker = true
                    } label: {
                        Label("Change Icon", systemImage: "face.smiling")
                    }

                    Button {
                        showingNewHome = true
                    } label: {
                        Label("New Home", systemImage: "plus")
                    }

                    Button {
                        let demo = HomeManager.createDemoHome(context: viewContext)
                        DemoSetup.install(into: demo, context: viewContext)
                        navigationState.selectedHome = demo
                    } label: {
                        Label("New Demo Home", systemImage: "house.and.flag")
                    }

                    if home?.isDemo == true {
                        Button {
                            showingResetDemo = true
                        } label: {
                            Label("Reset Demo", systemImage: "arrow.counterclockwise")
                        }
                    }

                    Divider()
                    Button(role: .destructive) {
                        showingDeleteHome = true
                    } label: {
                        Label("Delete Home", systemImage: "trash")
                    }
                } label: {
                    Label("Home Settings", systemImage: "ellipsis.circle")
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
        .alert("Rename Home", isPresented: $showingRenameHome) {
            TextField("Home name", text: $homeRenameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                home?.name = homeRenameText
                try? viewContext.save()
            }
            .disabled(homeRenameText.isEmpty)
        }
        .alert("New Home", isPresented: $showingNewHome) {
            NewHomeAlert { name in
                let newHome = HomeManager.createHome(name: name, context: viewContext)
                navigationState.selectedHome = newHome
            }
        }
        .alert("Delete Home?", isPresented: $showingDeleteHome) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let home {
                    let myHome = HomeManager.bootstrap(context: viewContext)
                    navigationState.selectedHome = myHome
                    viewContext.delete(home)
                    try? viewContext.save()
                }
            }
        } message: {
            Text("This will permanently delete this home and all its dashboards, data sources, and widgets.")
        }
        .sheet(isPresented: $showingAdd) {
            DashboardTemplatePickerView(
                home: navigationState.selectedHome,
                dataSources: Array(dataSources),
                onCreated: { _ in }
            )
            .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingIconPicker) {
            HomeIconPickerView(currentIcon: home?.wrappedIcon ?? "house") { icon in
                home?.icon = icon
                try? viewContext.save()
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

struct HomeIconPickerView: View {
    let currentIcon: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let icons: [(group: String, icons: [String])] = [
        ("Home", ["house", "house.fill", "house.and.flag", "house.lodge", "building.2", "building"]),
        ("Nature", ["leaf", "tree", "sun.max", "cloud", "snowflake", "drop"]),
        ("Devices", ["lightbulb", "fan", "heater.vertical", "refrigerator", "washer", "oven"]),
        ("Rooms", ["bed.double", "bathtub", "sofa", "chair.lounge", "cabinet", "table.furniture"]),
        ("Outdoor", ["car", "bicycle", "tent", "mountain.2", "figure.walk", "pawprint"]),
        ("Other", ["heart", "star", "bolt", "flame", "wrench", "gearshape"]),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(icons, id: \.group) { group in
                    Section(group.group) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                            ForEach(group.icons, id: \.self) { icon in
                                Button {
                                    onSelect(icon)
                                    dismiss()
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            currentIcon == icon
                                                ? Color.accentColor.opacity(0.2)
                                                : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Choose Icon")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
