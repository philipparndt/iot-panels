import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            DataSourceListView()
        } detail: {
            Text("Select a data source")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
