import SwiftUI

struct DataSourceDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dataSource: DataSource?

    @State private var name = ""
    @State private var backendType: BackendType = .influxDB2
    @State private var url = ""
    @State private var token = ""
    @State private var organization = ""
    @State private var bucket = ""

    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var showingGuidedSetup = false

    enum TestResult {
        case success
        case failure(String)
    }

    var isEditing: Bool { dataSource != nil }

    var body: some View {
        let form = Form {
            Section("General") {
                TextField("Name", text: $name)
                Picker("Type", selection: $backendType) {
                    ForEach(BackendType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            if backendType == .demo {
                Section {
                    Label("This data source generates realistic demo data for testing. No network connection required.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if backendType == .influxDB2 && !isEditing {
                Section {
                    Button {
                        showingGuidedSetup = true
                    } label: {
                        Label("Setup with Login", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Guided Setup")
                } footer: {
                    Text("Sign in with username and password to auto-discover organizations and buckets. An API token will be created automatically.")
                }
            }

            if backendType == .influxDB2 {
                Section("Connection") {
                    TextField("URL", text: $url)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Token", text: $token)
                }

                Section("InfluxDB 2") {
                    TextField("Organization", text: $organization)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Bucket", text: $bucket)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            if isEditing, let dataSource {
                Section {
                    NavigationLink {
                        SavedQueryListView(dataSource: dataSource)
                    } label: {
                        Label("Queries", systemImage: "magnifyingglass")
                    }
                }
            }

            Section {
                Button(action: testConnection) {
                    if isTesting {
                        ProgressView()
                    } else {
                        Text("Test Connection")
                    }
                }
                .disabled(backendType == .influxDB2 ? (url.isEmpty || token.isEmpty || isTesting) : isTesting)

                if let testResult {
                    switch testResult {
                    case .success:
                        Label("Connection successful", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showingGuidedSetup) {
            InfluxDB2SetupView { result in
                url = result.url
                token = result.token
                organization = result.organization
                bucket = result.bucket
                showingGuidedSetup = false
                if name.isEmpty {
                    name = "\(result.organization) / \(result.bucket)"
                }
            }
        }

        if isEditing {
            form
                .navigationTitle(name)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save)
                            .disabled(name.isEmpty || (backendType == .influxDB2 && url.isEmpty))
                    }
                }
                .onAppear(perform: loadDataSource)
        } else {
            NavigationStack {
                form
                    .navigationTitle("New Data Source")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add", action: save)
                                .disabled(name.isEmpty || (backendType == .influxDB2 && (url.isEmpty || token.isEmpty)))
                        }
                    }
            }
        }
    }

    private func loadDataSource() {
        guard let dataSource else { return }
        name = dataSource.wrappedName
        backendType = dataSource.wrappedBackendType
        url = dataSource.wrappedUrl
        token = dataSource.wrappedToken
        organization = dataSource.wrappedOrganization
        bucket = dataSource.wrappedBucket
    }

    private func save() {
        let target = dataSource ?? DataSource(context: viewContext)

        if dataSource == nil {
            target.id = UUID()
            target.createdAt = Date()
        }

        target.name = name
        target.backendType = backendType.rawValue
        target.url = url
        target.token = token
        target.organization = organization
        target.bucket = bucket
        target.modifiedAt = Date()

        try? viewContext.save()
        dismiss()
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let service: any DataSourceServiceProtocol
        if backendType == .demo {
            service = DemoService()
        } else {
            service = InfluxDB2Service(url: url, token: token, organization: organization, bucket: bucket)
        }

        Task {
            do {
                let success = try await service.testConnection()
                await MainActor.run {
                    testResult = success ? .success : .failure("Connection refused")
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }
}

#Preview("New") {
    DataSourceDetailView(dataSource: nil)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
