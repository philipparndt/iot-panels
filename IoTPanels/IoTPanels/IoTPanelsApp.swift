import SwiftUI

@main
struct IoTPanelsApp: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @State private var navigationState = NavigationState()
    @State private var importAlertMessage: String?
    @State private var showImportAlert = false

    var body: some Scene {
        WindowGroup {
            if persistenceController.isLoaded {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environment(navigationState)
                    .onAppear {
                        if navigationState.selectedHome == nil {
                            let home = HomeManager.bootstrap(context: persistenceController.container.viewContext)
                            navigationState.selectedHome = home
                        }
                    }
                    .onOpenURL { url in
                        if url.pathExtension == "mqttbroker" {
                            handleBrokerImport(url)
                        } else {
                            navigationState.handleURL(url)
                        }
                    }
                    .alert("Import", isPresented: $showImportAlert) {
                        Button("OK") {}
                    } message: {
                        Text(importAlertMessage ?? "")
                    }
            } else {
                ProgressView("Loading...")
            }
        }
    }

    private func handleBrokerImport(_ url: URL) {
        let context = persistenceController.container.viewContext
        do {
            let ds = try BrokerImportExport.importBroker(from: url, context: context)
            importAlertMessage = "Broker '\(ds.wrappedName)' was imported successfully."
            showImportAlert = true
        } catch {
            importAlertMessage = "Failed to import broker: \(error.localizedDescription)"
            showImportAlert = true
        }
    }
}
