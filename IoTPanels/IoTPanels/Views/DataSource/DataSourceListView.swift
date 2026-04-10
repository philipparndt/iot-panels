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
    @State private var selectedDataSource: DataSource?

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
                        Divider()
                    }
                    Button(role: .destructive) {
                        delete(dataSource)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: deleteDataSources)
        }
        .navigationTitle("Data Sources")
        #if os(iOS)
        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
        #endif
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
        #if os(iOS)
        .sheet(isPresented: $showExportShare) {
            if let url = exportFileURL {
                ShareSheetView(activityItems: [url])
            }
        }
        #else
        // On macOS the export flow surfaces as a file exporter from the call site; the sheet is a no-op.
        .onChange(of: showExportShare) { _, newValue in
            if newValue, let url = exportFileURL {
                MacFileExporter.revealOrExport(url: url)
                showExportShare = false
            }
        }
        #endif
        .onAppear {
            if navigationState.showAddDataSource {
                navigationState.showAddDataSource = false
                showingAddSheet = true
            }
            consumeNavigateToDataSource()
        }
        .onChange(of: navigationState.navigateToDataSourceId) {
            consumeNavigateToDataSource()
        }
        .navigationDestination(item: $selectedDataSource) { ds in
            DataSourceDetailView(dataSource: ds)
        }
    }

    private func consumeNavigateToDataSource() {
        guard let targetId = navigationState.navigateToDataSourceId else { return }
        navigationState.navigateToDataSourceId = nil
        if let ds = dataSources.first(where: { $0.id == targetId }) {
            selectedDataSource = ds
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

    private func delete(_ dataSource: DataSource) {
        withAnimation {
            viewContext.delete(dataSource)
            try? viewContext.save()
        }
    }
}

// MARK: - MQTT Connection Status

#if canImport(CocoaMQTT)
struct MQTTConnectionStatusView: View {
    let dataSource: DataSource
    @State private var isConnected = false
    @State private var errorMessage: String?
    @State private var cancellables: Set<AnyCancellable> = []

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .onAppear { startMonitoring() }
        .onDisappear { cancellables.removeAll() }
    }

    private var statusColor: Color {
        if isConnected { return .green }
        if errorMessage != nil { return .red }
        return .secondary.opacity(0.5)
    }

    private var statusLabel: String {
        if isConnected { return "Connected" }
        if errorMessage != nil { return "Error" }
        return "Connecting…"
    }

    private func startMonitoring() {
        let service = MQTTService(dataSource: dataSource)
        let key = service.connectionKey
        let manager = MQTTConnectionManager.shared

        manager.ensureConnected(for: service)
        refreshState(manager: manager, key: key)

        manager.connectionStateChanged
            .filter { $0 == key }
            .receive(on: DispatchQueue.main)
            .sink { _ in
                refreshState(manager: manager, key: key)
            }
            .store(in: &cancellables)

        manager.messageReceived
            .filter { $0.connectionKey == key }
            .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true)
            .sink { _ in
                refreshState(manager: manager, key: key)
            }
            .store(in: &cancellables)
    }

    private func refreshState(manager: MQTTConnectionManager, key: String) {
        isConnected = manager.isConnected(key: key)
        errorMessage = isConnected ? nil : manager.connectionError(key: key)
    }
}
/// A dismissible banner that monitors all MQTT data sources in the current home
/// and surfaces connection errors prominently. Placed in ContentView / MacRootView
/// so the user sees errors regardless of which tab they're on.
struct MQTTConnectionBannerView: View {
    let home: Home?
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest private var mqttSources: FetchedResults<DataSource>
    @Environment(NavigationState.self) private var navigationState
    @State private var errors: [(id: UUID, name: String, error: String)] = []
    @State private var dismissed = false
    @State private var cancellables: Set<AnyCancellable> = []

    init(home: Home?) {
        self.home = home
        let predicate: NSPredicate
        if let home {
            predicate = NSPredicate(format: "home == %@ AND backendType == %@", home, BackendType.mqtt.rawValue)
        } else {
            predicate = NSPredicate(format: "home == nil AND backendType == %@", BackendType.mqtt.rawValue)
        }
        _mqttSources = FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DataSource.name, ascending: true)], predicate: predicate)
    }

    var body: some View {
        Group {
            if !dismissed, !errors.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(errors, id: \.id) { entry in
                            Button {
                                navigationState.navigateToDataSourceId = entry.id
                                navigationState.selectedTab = .dataSources
                            } label: {
                                Text("\(entry.name): \(entry.error)")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .underline()
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation { dismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { setupMonitoring() }
        .onChange(of: mqttSources.count) { setupMonitoring() }
    }

    private func setupMonitoring() {
        cancellables.removeAll()
        let manager = MQTTConnectionManager.shared

        for ds in mqttSources {
            manager.ensureConnected(for: MQTTService(dataSource: ds))
        }

        refreshErrors()

        manager.connectionStateChanged
            .receive(on: DispatchQueue.main)
            .sink { _ in
                refreshErrors()
                if !errors.isEmpty { dismissed = false }
            }
            .store(in: &cancellables)
    }

    private func refreshErrors() {
        let manager = MQTTConnectionManager.shared
        var newErrors: [(id: UUID, name: String, error: String)] = []
        for ds in mqttSources {
            guard let dsId = ds.id else { continue }
            let key = MQTTService(dataSource: ds).connectionKey
            if !manager.isConnected(key: key),
               let error = manager.connectionError(key: key) {
                newErrors.append((id: dsId, name: ds.wrappedName, error: error))
            }
        }
        errors = newErrors
    }
}

#else
struct MQTTConnectionStatusView: View {
    let dataSource: DataSource
    var body: some View { EmptyView() }
}

struct MQTTConnectionBannerView: View {
    let home: Home?
    var body: some View { EmptyView() }
}
#endif

// MARK: - Share Sheet

#if os(iOS)
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#Preview {
    NavigationStack {
        DataSourceListView(home: nil)
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environment(NavigationState())
}
