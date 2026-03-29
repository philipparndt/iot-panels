import SwiftUI
import CoreData

@Observable
class NavigationState {
    var selectedTab: AppTab = .dashboards
    var navigateToWidgetDesignId: UUID?
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
        // iotpanels://widget/<uuid>
        guard url.scheme == "iotpanels",
              url.host == "widget",
              let idString = url.pathComponents.last,
              let uuid = UUID(uuidString: idString) else { return }

        selectedTab = .widgets
        navigateToWidgetDesignId = uuid
    }
}
