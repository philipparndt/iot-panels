import SwiftUI

@main
struct IoTPanelsApp: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @State private var navigationState = NavigationState()
    @State private var importAlertMessage: String?
    @State private var showImportAlert = false
    @Environment(\.scenePhase) private var scenePhase

    static let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")

    var body: some Scene {
        WindowGroup {
            if persistenceController.isLoaded {
                rootView
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environment(navigationState)
                    .onAppear {
                        let context = persistenceController.container.viewContext
                        if Self.isUITesting {
                            // Reset demo data to avoid duplicates across runs
                            DemoSetup.reset(context: context)
                            let home = HomeManager.demoHome(context: context)
                            navigationState.selectedHome = home
                        } else if navigationState.selectedHome == nil {
                            let home = HomeManager.bootstrap(context: context)
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
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 800)
        #endif

        #if os(macOS)
        WindowGroup("Chart Explorer", for: ChartExplorerWindowID.self) { $windowID in
            if let windowID {
                ChartExplorerWindowView(panelID: windowID.panelID)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
        .defaultSize(width: 900, height: 650)

        Settings {
            NavigationStack {
                AboutView()
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .frame(minWidth: 480, minHeight: 400)
        }
        #endif
    }

    @ViewBuilder
    private var rootView: some View {
        #if os(macOS)
        MacRootView()
        #else
        ContentView()
        #endif
    }

    /// Keeps MQTT connections live across app suspension. On background we cleanly
    /// disconnect so iOS can suspend the process; on foreground we force a fresh
    /// reconnect because sockets typically do not survive iOS background suspension,
    /// and CocoaMQTT's `autoReconnect` timer cannot be relied on to recover reliably.
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        #if canImport(CocoaMQTT)
        switch phase {
        case .background:
            MQTTConnectionManager.shared.handleAppDidEnterBackground()
        case .active:
            MQTTConnectionManager.shared.handleAppWillEnterForeground()
        case .inactive:
            break
        @unknown default:
            break
        }
        #endif
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
