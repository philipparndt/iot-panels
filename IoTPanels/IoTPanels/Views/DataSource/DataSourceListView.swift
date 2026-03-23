import SwiftUI

struct DataSourceListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DataSource.name, ascending: true)],
        animation: .default
    )
    private var dataSources: FetchedResults<DataSource>

    @State private var showingAddSheet = false

    var body: some View {
        List {
            ForEach(dataSources) { dataSource in
                NavigationLink {
                    DataSourceDetailView(dataSource: dataSource)
                } label: {
                    VStack(alignment: .leading) {
                        Text(dataSource.wrappedName)
                            .font(.headline)
                        Text(dataSource.wrappedBackendType.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteDataSources)
        }
        .navigationTitle("Data Sources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            DataSourceDetailView(dataSource: nil)
        }
    }

    private func deleteDataSources(offsets: IndexSet) {
        withAnimation {
            offsets.map { dataSources[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        DataSourceListView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
