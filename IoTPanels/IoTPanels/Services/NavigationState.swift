import SwiftUI

@Observable
class NavigationState {
    var selectedTab: AppTab = .widgets
    var navigateToWidgetDesignId: UUID?

    enum AppTab: Hashable {
        case widgets
        case dashboards
        case dataSources
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
