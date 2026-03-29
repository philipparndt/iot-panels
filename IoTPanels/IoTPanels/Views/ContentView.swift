import SwiftUI

struct ContentView: View {
    @Environment(NavigationState.self) private var navigationState
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        @Bindable var nav = navigationState

        TabView(selection: $nav.selectedTab) {
            Tab("Dashboards", systemImage: "square.grid.2x2", value: .dashboards) {
                NavigationStack {
                    DashboardListView()
                }
            }

            Tab("Widgets", systemImage: "rectangle.on.rectangle.angled", value: .widgets) {
                WidgetDesignListView()
            }

            Tab("Data Sources", systemImage: "server.rack", value: .dataSources) {
                NavigationStack {
                    DataSourceListView()
                }
            }
        }
    }

}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(NavigationState())
}
