import SwiftUI
import Combine
import UniformTypeIdentifiers

struct DataSourceListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(NavigationState.self) private var navigationState

    let home: Home?

    @FetchRequest private var dataSources: FetchedResults<DataSource>

    init(home: Home?) {
        self.home = home
        let predicate: NSPredicate
        if let home {
            predicate = NSPredicate(format: "home == %@", home)
        } else {
            predicate = NSPredicate(format: "home == nil")
        }
        _dataSources = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \DataSource.name, ascending: true)],
            predicate: predicate,
            animation: .default
        )
    }

    @State private var showingAddSheet = false
    @State private var showingImportPicker = false
    @State private var importAlertMessage: String?
    @State private var showImportAlert = false
    @State private var isEditing = false

    var body: some View {
        List {
            if dataSources.isEmpty {
                ContentUnavailableView {
                    Label("No Data Sources", systemImage: "server.rack")
                } description: {
                    Text("Add a data source to connect to InfluxDB, Prometheus, MQTT, or use the built-in demo data.")
                } actions: {
                    Button("Add Data Source") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            ForEach(dataSources) { dataSource in
                NavigationLink {
                    DataSourceDetailView(dataSource: dataSource)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(dataSource.wrappedName)
                                .font(.headline)
                            Text(dataSource.wrappedBackendType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if dataSource.wrappedBackendType == .mqtt {
                            MQTTConnectionStatusView(dataSource: dataSource)
                        }
                    }
                }
                .contextMenu {
                    if dataSource.wrappedBackendType == .mqtt {
                        Button {
                            exportBroker(dataSource, includeSecrets: true)
                        } label: {
                            Label("Share (with credentials)", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            exportBroker(dataSource, includeSecrets: false)
                        } label: {
                            Label("Share (without credentials)", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onDelete(perform: deleteDataSources)
        }
        .navigationTitle("Data Sources")
        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Data Source", systemImage: "plus")
                    }
                    Button(action: { showingImportPicker = true }) {
                        Label("Import .mqttbroker", systemImage: "square.and.arrow.down")
                    }
                    Button(action: { isEditing.toggle() }) {
                        Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                    }
                } label: {
                    Label("Menu", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            DataSourceDetailView(dataSource: nil)
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.mqttBroker],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Import", isPresented: $showImportAlert) {
            Button("OK") {}
        } message: {
            Text(importAlertMessage ?? "")
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportFileURL {
                ShareSheetView(activityItems: [url])
            }
        }
        .onAppear {
            if navigationState.showAddDataSource {
                navigationState.showAddDataSource = false
                showingAddSheet = true
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let ds = try BrokerImportExport.importBroker(from: url, context: viewContext)
                importAlertMessage = "Broker '\(ds.wrappedName)' was imported successfully."
                showImportAlert = true
            } catch {
                importAlertMessage = "Failed to import broker: \(error.localizedDescription)"
                showImportAlert = true
            }
        case .failure(let error):
            importAlertMessage = "Failed to open file: \(error.localizedDescription)"
            showImportAlert = true
        }
    }

    @State private var exportFileURL: URL?
    @State private var showExportShare = false

    private func exportBroker(_ dataSource: DataSource, includeSecrets: Bool) {
        do {
            let url = try BrokerImportExport.exportBroker(dataSource, includeSecrets: includeSecrets)
            exportFileURL = url
            showExportShare = true
        } catch {
            importAlertMessage = "Failed to export: \(error.localizedDescription)"
            showImportAlert = true
        }
    }

    private func deleteDataSources(offsets: IndexSet) {
        withAnimation {
            offsets.map { dataSources[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// MARK: - MQTT Connection Status

#if canImport(CocoaMQTT)
struct MQTTConnectionStatusView: View {
    let dataSource: DataSource
    @State private var isConnected = false
    @State private var cancellable: AnyCancellable?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Offline")
                .font(.caption2)
                .foregroundStyle(isConnected ? .green : .secondary)
        }
        .onAppear { startMonitoring() }
        .onDisappear { cancellable?.cancel() }
    }

    private func startMonitoring() {
        let service = MQTTService(dataSource: dataSource)
        let key = service.connectionKey
        isConnected = MQTTConnectionManager.shared.isConnected(key: key)

        cancellable = MQTTConnectionManager.shared.messageReceived
            .filter { $0.connectionKey == key }
            .receive(on: DispatchQueue.main)
            .sink { _ in
                isConnected = MQTTConnectionManager.shared.isConnected(key: key)
            }
    }
}
#else
struct MQTTConnectionStatusView: View {
    let dataSource: DataSource
    var body: some View { EmptyView() }
}
#endif

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DataSourceListView(home: nil)
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environment(NavigationState())
}
