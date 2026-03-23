import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Dashboards", systemImage: "square.grid.2x2") {
                NavigationStack {
                    DashboardListView()
                }
            }

            Tab("Data Sources", systemImage: "server.rack") {
                NavigationSplitView {
                    DataSourceListView()
                } detail: {
                    Text("Select a data source")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
