import SwiftUI

@main
struct IoTPanelsApp: App {
    let persistenceController = PersistenceController.shared
    @State private var navigationState = NavigationState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(navigationState)
                .onOpenURL { url in
                    navigationState.handleURL(url)
                }
        }
    }
}
