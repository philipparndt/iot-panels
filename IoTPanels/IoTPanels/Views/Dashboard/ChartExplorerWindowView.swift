#if os(macOS)
import SwiftUI

/// Thin wrapper that resolves a `DashboardPanel` UUID into the real managed
/// object and passes it to `ChartExplorerView`. Used by the macOS
/// "Chart Explorer" `WindowGroup(for: UUID.self)` scene.
struct ChartExplorerWindowView: View {
    let panelID: UUID
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        if let panel = fetchPanel() {
            ChartExplorerView(panel: panel)
        } else {
            ContentUnavailableView("Panel Not Found", systemImage: "chart.xyaxis.line")
        }
    }

    private func fetchPanel() -> DashboardPanel? {
        let request = DashboardPanel.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", panelID as CVarArg)
        request.fetchLimit = 1
        return (try? viewContext.fetch(request))?.first
    }
}
#endif
