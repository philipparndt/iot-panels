import SwiftUI

struct DashboardListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Dashboard.name, ascending: true)],
        animation: .default
    )
    private var dashboards: FetchedResults<Dashboard>

    @State private var showingAdd = false

    var body: some View {
        List {
            if dashboards.isEmpty {
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
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAdd = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
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
