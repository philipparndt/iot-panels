import SwiftUI
import CoreData

@Observable
class NavigationState {
    var selectedTab: AppTab = .dashboards
    var navigateToWidgetDesignId: UUID?
    var navigateToSavedQueryId: UUID?
    var showAddDataSource = false
    var selectedHome: Home? {
        didSet { homeVersion += 1 }
    }
    private(set) var homeVersion: Int = 0

    var homePredicate: NSPredicate {
        if let home = selectedHome {
            return NSPredicate(format: "home == %@", home)
        }
        return NSPredicate(format: "home == nil")
    }

    enum AppTab: Hashable {
        case widgets
        case dashboards
        case dataSources
        case about
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "iotpanels",
              let host = url.host,
              let idString = url.pathComponents.last,
              let uuid = UUID(uuidString: idString) else { return }

        let context = PersistenceController.shared.container.viewContext

        switch host {
        case "widget":
            // iotpanels://widget/<uuid>
            // Switch to the correct home for this widget design
            let request = WidgetDesign.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            request.fetchLimit = 1
            if let design = (try? context.fetch(request))?.first {
                selectedHome = design.home
            }
            selectedTab = .widgets
            navigateToWidgetDesignId = uuid

        case "query":
            // iotpanels://query/<uuid>
            // Switch to the correct home for this saved query's data source
            let request = SavedQuery.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            request.fetchLimit = 1
            if let query = (try? context.fetch(request))?.first {
                selectedHome = query.dataSource?.home
            }
            selectedTab = .dataSources
            navigateToSavedQueryId = uuid

        default:
            break
        }
    }
}
