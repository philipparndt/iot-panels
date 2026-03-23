import SwiftUI

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var dashboard: Dashboard

    @State private var showingAddPanel = false
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let panels = dashboard.sortedPanels
                if panels.isEmpty {
                    ContentUnavailableView(
                        "No Panels",
                        systemImage: "rectangle.on.rectangle",
                        description: Text("Tap + to add a panel from your saved queries.")
                    )
                    .padding(.top, 60)
                } else {
                    ForEach(Array(panels.enumerated()), id: \.element.objectID) { _, panel in
                        PanelCardView(panel: panel)
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewContext.delete(panel)
                                        try? viewContext.save()
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(dashboard.wrappedName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddPanel = true }) {
                    Label("Add Panel", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPanel) {
            AddPanelView(dashboard: dashboard)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}
