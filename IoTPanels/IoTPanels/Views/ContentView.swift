import SwiftUI

struct ContentView: View {
    @Environment(NavigationState.self) private var navigationState
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Home.sortOrder, ascending: true)],
        animation: .default
    )
    private var homes: FetchedResults<Home>

    @State private var showingNewHome = false
    @State private var savedQueryForSheet: SavedQuery?

    var body: some View {
        @Bindable var nav = navigationState

        VStack(spacing: 0) {
            homeSelector
            TabView(selection: $nav.selectedTab) {
                Tab("Dashboards", systemImage: "square.grid.2x2", value: .dashboards) {
                    NavigationStack {
                        DashboardListView(home: navigationState.selectedHome)
                    }
                }

                Tab("Widgets", systemImage: "rectangle.on.rectangle.angled", value: .widgets) {
                    WidgetDesignListView(home: navigationState.selectedHome)
                }

                Tab("Data Sources", systemImage: "server.rack", value: .dataSources) {
                    NavigationStack {
                        DataSourceListView(home: navigationState.selectedHome)
                    }
                }

                Tab("About", systemImage: "info.circle", value: .about) {
                    NavigationStack {
                        AboutView()
                    }
                }
            }
            .id(navigationState.homeVersion)
        }
        .alert("New Home", isPresented: $showingNewHome) {
            NewHomeAlert { name in
                let home = HomeManager.createHome(name: name, context: viewContext)
                navigationState.selectedHome = home
            }
        }
        .onChange(of: navigationState.navigateToSavedQueryId, initial: true) {
            guard let queryId = navigationState.navigateToSavedQueryId else { return }
            navigationState.navigateToSavedQueryId = nil
            let request = SavedQuery.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", queryId as CVarArg)
            request.fetchLimit = 1
            if let query = (try? viewContext.fetch(request))?.first {
                savedQueryForSheet = query
            }
        }
        .sheet(item: $savedQueryForSheet) { query in
            NavigationStack {
                if let dataSource = query.dataSource {
                    SavedQueryDetailView(dataSource: dataSource, savedQuery: query)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { savedQueryForSheet = nil }
                            }
                        }
                }
            }
            .environment(\.managedObjectContext, viewContext)
        }
    }

    private var homeSelector: some View {
        Menu {
            ForEach(homes) { home in
                Button {
                    navigationState.selectedHome = home
                } label: {
                    Label(home.wrappedName, systemImage: home.wrappedIcon)
                    if navigationState.selectedHome?.objectID == home.objectID {
                        Image(systemName: "checkmark")
                    }
                }
            }
            Divider()
            Button {
                showingNewHome = true
            } label: {
                Label("New Home", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: navigationState.selectedHome?.wrappedIcon ?? "house")
                Text(navigationState.selectedHome?.wrappedName ?? "Home")
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

struct NewHomeAlert: View {
    let onSave: (String) -> Void
    @State private var name = ""

    var body: some View {
        TextField("Home name", text: $name)
        Button("Cancel", role: .cancel) {}
        Button("Create") {
            onSave(name)
        }
        .disabled(name.isEmpty)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(NavigationState())
}
