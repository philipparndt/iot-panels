#if os(macOS)
import SwiftUI

/// macOS top-level shell. Replaces the iOS `TabView` in `ContentView` with a
/// `NavigationSplitView` sidebar that lists the same four sections (Dashboards,
/// Widgets, Data Sources, About). Each detail pane reuses the exact SwiftUI
/// view the iOS build renders inside its corresponding tab.
struct MacRootView: View {
    @Environment(NavigationState.self) private var navigationState
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Home.sortOrder, ascending: true)],
        animation: .default
    )
    private var homes: FetchedResults<Home>

    @State private var selection: NavigationState.AppTab = .dashboards
    @State private var showingNewHome = false

    var body: some View {
        @Bindable var nav = navigationState

        NavigationSplitView {
            List(selection: $selection) {
                Section("Home") {
                    homeMenu
                }

                Section {
                    Label("Dashboards", systemImage: "square.grid.2x2")
                        .tag(NavigationState.AppTab.dashboards)
                    Label("Widgets", systemImage: "rectangle.on.rectangle.angled")
                        .tag(NavigationState.AppTab.widgets)
                    Label("Data Sources", systemImage: "server.rack")
                        .tag(NavigationState.AppTab.dataSources)
                    Label("About", systemImage: "info.circle")
                        .tag(NavigationState.AppTab.about)
                }
            }
            .navigationTitle("IoT Panels")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            NavigationStack {
                detailView
            }
            .id(navigationState.homeVersion)
        }
        .onChange(of: selection) { _, newValue in
            nav.selectedTab = newValue
        }
        .onChange(of: nav.selectedTab) { _, newValue in
            if newValue != selection { selection = newValue }
        }
        .frame(minWidth: 800, minHeight: 500)
        .alert("New Home", isPresented: $showingNewHome) {
            NewHomeAlert { name in
                let home = HomeManager.createHome(name: name, context: viewContext)
                navigationState.selectedHome = home
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .dashboards:
            DashboardListView(home: navigationState.selectedHome)
        case .widgets:
            WidgetDesignListView(home: navigationState.selectedHome)
        case .dataSources:
            DataSourceListView(home: navigationState.selectedHome)
        case .about:
            AboutView()
        }
    }

    private var homeMenu: some View {
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
            Button {
                let demo = HomeManager.createDemoHome(context: viewContext)
                DemoSetup.install(into: demo, context: viewContext)
                navigationState.selectedHome = demo
            } label: {
                Label("New Demo Home", systemImage: "house.and.flag")
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
        }
    }
}
#endif
