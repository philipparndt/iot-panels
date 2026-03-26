import SwiftUI

@main
struct IoTPanelsApp: App {
    let persistenceController = PersistenceController.shared
    @State private var navigationState = NavigationState()
    @State private var importAlertMessage: String?
    @State private var showImportAlert = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(navigationState)
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
