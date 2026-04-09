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
    @State private var showingRenameHome = false
    @State private var showingDeleteHome = false
    @State private var showingResetDemo = false
    @State private var showingIconPicker = false
    @State private var homeRenameText = ""

    private var selectedHome: Home? { navigationState.selectedHome }

    var body: some View {
        @Bindable var nav = navigationState

        NavigationSplitView {
            List(selection: $selection) {
                Section("Home") {
                    HStack(spacing: 4) {
                        homeMenu
                        Spacer()
                        homeSettingsMenu
                    }
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
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
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
        .alert("Rename Home", isPresented: $showingRenameHome) {
            TextField("Home name", text: $homeRenameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                selectedHome?.name = homeRenameText
                try? viewContext.save()
            }
            .disabled(homeRenameText.isEmpty)
        }
        .alert("Delete \"\(selectedHome?.wrappedName ?? "Home")\"?", isPresented: $showingDeleteHome) {
            Button("Cancel", role: .cancel) {}
            Button("Delete \"\(selectedHome?.wrappedName ?? "Home")\"", role: .destructive) {
                if let home = selectedHome {
                    let fallback = HomeManager.bootstrap(context: viewContext)
                    navigationState.selectedHome = fallback
                    viewContext.delete(home)
                    try? viewContext.save()
                }
            }
        } message: {
            Text("This will permanently delete \"\(selectedHome?.wrappedName ?? "this home")\" and all its dashboards, data sources, and widgets.")
        }
        .alert("Reset Demo?", isPresented: $showingResetDemo) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                DemoSetup.reset(context: viewContext)
            }
        } message: {
            Text("This will delete all demo dashboards, data sources, and widgets, then recreate them.")
        }
        .sheet(isPresented: $showingIconPicker) {
            HomeIconPickerView(currentIcon: selectedHome?.wrappedIcon ?? "house") { icon in
                selectedHome?.icon = icon
                try? viewContext.save()
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
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var homeSettingsMenu: some View {
        Menu {
            Button {
                homeRenameText = selectedHome?.wrappedName ?? ""
                showingRenameHome = true
            } label: {
                Label("Rename Home", systemImage: "pencil")
            }
            .disabled(selectedHome == nil)

            Button {
                showingIconPicker = true
            } label: {
                Label("Change Icon", systemImage: "face.smiling")
            }
            .disabled(selectedHome == nil)

            if selectedHome?.isDemo == true {
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
            .disabled(selectedHome == nil)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
#endif
