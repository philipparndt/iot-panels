import SwiftUI

struct DataSourceDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dataSource: DataSource?

    @State private var name = ""
    @State private var backendType: BackendType = .influxDB2

    // InfluxDB fields
    @State private var url = ""
    @State private var influxAuthMethod: InfluxAuthMethod = .token
    @State private var token = ""
    @State private var influxUsername = ""
    @State private var influxPassword = ""
    @State private var organization = ""
    @State private var bucket = ""

    // MQTT fields
    @State private var mqttHostname = ""
    @State private var mqttPort = "1883"
    @State private var mqttProtocolMethod: MQTTProtocolMethod = .mqtt
    @State private var mqttProtocolVersion: MQTTProtocolVersion = .mqtt3
    @State private var mqttBasePath = ""
    @State private var mqttSsl = false
    @State private var mqttUntrustedSSL = false
    @State private var mqttCertServerCA: MQTTCertificateFile?
    @State private var mqttAlpn = ""
    @State private var mqttUsernamePasswordAuth = false
    @State private var mqttUsername = ""
    @State private var mqttPassword = ""
    @State private var mqttCertificateAuth = false
    @State private var mqttCertP12: MQTTCertificateFile?
    @State private var mqttCertClientKeyPassword = ""
    @State private var mqttClientID = ""
    @State private var mqttSubscriptions = [MQTTTopicSubscription()]

    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var showingGuidedSetup = false
    @State private var shareFileURL: URL?
    @State private var showShareSheet = false
    @FocusState private var nameFieldFocused: Bool

    enum TestResult {
        case success
        case failure(String)
    }

    var isEditing: Bool { dataSource != nil }

    private var canSave: Bool {
        guard !name.isEmpty else { return false }
        switch backendType {
        case .influxDB2:
            guard !url.isEmpty else { return false }
            switch influxAuthMethod {
            case .token:
                return isEditing || !token.isEmpty
            case .usernamePassword:
                return !influxUsername.isEmpty && (isEditing || !influxPassword.isEmpty)
            }
        case .mqtt:
            return !mqttHostname.isEmpty
        case .demo:
            return true
        }
    }

    private var canTest: Bool {
        guard !isTesting else { return false }
        switch backendType {
        case .influxDB2:
            guard !url.isEmpty else { return false }
            switch influxAuthMethod {
            case .token:
                return !token.isEmpty
            case .usernamePassword:
                return !influxUsername.isEmpty && !influxPassword.isEmpty
            }
        case .mqtt:
            return !mqttHostname.isEmpty
        case .demo:
            return true
        }
    }

    var body: some View {
        let form = Form {
            Section("General") {
                TextField("Name", text: $name)
                    .focused($nameFieldFocused)
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
                        Label("Setup Wizard", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Guided Setup")
                } footer: {
                    Text("Connect to your InfluxDB server and select an organization and bucket.")
                }
            }

            if backendType == .influxDB2 {
                Section("InfluxDB 2") {
                    NavigationLink {
                        InfluxDBSettingsFormView(
                            url: $url,
                            authMethod: $influxAuthMethod,
                            token: $token,
                            username: $influxUsername,
                            password: $influxPassword,
                            organization: $organization,
                            bucket: $bucket
                        )
                    } label: {
                        HStack {
                            Label("Connection Settings", systemImage: "server.rack")
                            Spacer()
                            if !url.isEmpty {
                                Text(url.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            if backendType == .mqtt {
                Section("Broker") {
                    NavigationLink {
                        MQTTBrokerFormView(
                            hostname: $mqttHostname,
                            port: $mqttPort,
                            protocolMethod: $mqttProtocolMethod,
                            protocolVersion: $mqttProtocolVersion,
                            basePath: $mqttBasePath,
                            ssl: $mqttSsl,
                            untrustedSSL: $mqttUntrustedSSL,
                            certServerCA: $mqttCertServerCA,
                            alpn: $mqttAlpn,
                            usernamePasswordAuth: $mqttUsernamePasswordAuth,
                            username: $mqttUsername,
                            password: $mqttPassword,
                            certificateAuth: $mqttCertificateAuth,
                            certP12: $mqttCertP12,
                            certClientKeyPassword: $mqttCertClientKeyPassword,
                            clientID: $mqttClientID,
                            subscriptions: $mqttSubscriptions
                        )
                    } label: {
                        HStack {
                            Label("Broker Settings", systemImage: "server.rack")
                            Spacer()
                            if !mqttHostname.isEmpty {
                                Text("\(mqttHostname):\(mqttPort)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
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

            if backendType != .demo {
                Section {
                    Button(action: testConnection) {
                        if isTesting {
                            ProgressView()
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(!canTest)

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
        }
        .sheet(isPresented: $showingGuidedSetup) {
            InfluxDB2SetupView { result in
                url = result.url
                influxAuthMethod = result.authMethod
                token = result.token
                influxUsername = result.username
                influxPassword = result.password
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
                    if backendType == .mqtt, let dataSource {
                        ToolbarItem(placement: .navigation) {
                            Menu {
                                Button {
                                    shareBroker(dataSource, includeSecrets: true)
                                } label: {
                                    Label("Share (with credentials)", systemImage: "square.and.arrow.up")
                                }
                                Button {
                                    shareBroker(dataSource, includeSecrets: false)
                                } label: {
                                    Label("Share (without credentials)", systemImage: "square.and.arrow.up")
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save)
                            .disabled(!canSave)
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    if let url = shareFileURL {
                        ShareSheetView(activityItems: [url])
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
                                .disabled(!canSave)
                        }
                    }
                    .onAppear { nameFieldFocused = true }
            }
        }
    }

    private func loadDataSource() {
        guard let dataSource else { return }
        name = dataSource.wrappedName
        backendType = dataSource.wrappedBackendType

        // InfluxDB
        url = dataSource.wrappedUrl
        influxAuthMethod = dataSource.wrappedInfluxAuthMethod
        token = dataSource.wrappedToken
        influxUsername = dataSource.wrappedUsername
        influxPassword = dataSource.wrappedPassword
        organization = dataSource.wrappedOrganization
        bucket = dataSource.wrappedBucket

        // MQTT
        mqttHostname = dataSource.wrappedHostname
        mqttPort = "\(dataSource.wrappedPort)"
        mqttProtocolMethod = dataSource.wrappedProtocolMethod
        mqttProtocolVersion = dataSource.wrappedProtocolVersion
        mqttBasePath = dataSource.wrappedBasePath
        mqttSsl = dataSource.wrappedSsl
        mqttUntrustedSSL = dataSource.wrappedUntrustedSSL
        mqttCertServerCA = dataSource.wrappedCertificates.first { $0.type == .serverCA }
        mqttAlpn = dataSource.wrappedAlpn
        mqttUsername = dataSource.wrappedUsername
        mqttPassword = dataSource.wrappedPassword
        mqttUsernamePasswordAuth = !dataSource.wrappedUsername.isEmpty
        mqttCertificateAuth = dataSource.wrappedCertificates.contains { $0.type == .p12 }
        mqttCertP12 = dataSource.wrappedCertificates.first { $0.type == .p12 }
        mqttCertClientKeyPassword = dataSource.wrappedCertClientKeyPassword
        mqttClientID = dataSource.wrappedClientID
        mqttSubscriptions = dataSource.wrappedSubscriptions
        if mqttSubscriptions.isEmpty {
            mqttSubscriptions = [MQTTTopicSubscription()]
        }
    }

    private func save() {
        let target = dataSource ?? DataSource(context: viewContext)

        if dataSource == nil {
            target.id = UUID()
            target.createdAt = Date()
        }

        target.name = name
        target.backendType = backendType.rawValue
        target.modifiedAt = Date()

        // InfluxDB fields
        target.url = url
        target.influxAuthMethod = influxAuthMethod.rawValue
        target.token = influxAuthMethod == .token ? token : nil
        target.organization = organization
        target.bucket = bucket

        // MQTT fields
        target.hostname = mqttHostname
        target.port = Int32(mqttPort) ?? 1883
        target.protocolMethod = mqttProtocolMethod.rawValue
        target.protocolVersion = mqttProtocolVersion.rawValue
        target.basePath = mqttBasePath
        target.ssl = mqttSsl
        target.untrustedSSL = mqttSsl && mqttUntrustedSSL
        target.wrappedAlpn = mqttAlpn
        if backendType == .influxDB2 && influxAuthMethod == .usernamePassword {
            target.username = influxUsername
            target.password = influxPassword
        } else {
            target.username = mqttUsernamePasswordAuth ? mqttUsername : nil
            target.password = mqttUsernamePasswordAuth ? mqttPassword : nil
        }
        target.clientID = mqttClientID.isEmpty ? nil : mqttClientID
        target.certClientKeyPassword = mqttCertificateAuth ? mqttCertClientKeyPassword : nil
        target.wrappedSubscriptions = mqttSubscriptions.filter { !$0.topic.trimmingCharacters(in: .whitespaces).isEmpty }

        // Build certificates array from individual pickers
        var certs: [MQTTCertificateFile] = []
        if let serverCA = mqttCertServerCA { certs.append(serverCA) }
        if mqttCertificateAuth, let p12 = mqttCertP12 { certs.append(p12) }
        target.wrappedCertificates = certs

        try? viewContext.save()
        dismiss()
    }

    private func shareBroker(_ dataSource: DataSource, includeSecrets: Bool) {
        do {
            let url = try BrokerImportExport.exportBroker(dataSource, includeSecrets: includeSecrets)
            shareFileURL = url
            showShareSheet = true
        } catch {
            testResult = .failure("Export failed: \(error.localizedDescription)")
        }
    }

    private func normalizedInfluxUrl() -> String {
        let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        switch backendType {
        case .demo:
            let service = DemoService()
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

        case .influxDB2:
            let resolvedUrl = normalizedInfluxUrl()
            let service: InfluxDB2Service
            if influxAuthMethod == .usernamePassword {
                service = InfluxDB2Service(url: resolvedUrl, username: influxUsername, password: influxPassword, organization: organization, bucket: bucket)
            } else {
                service = InfluxDB2Service(url: resolvedUrl, token: token, organization: organization, bucket: bucket)
            }
            Task {
                do {
                    let success = try await service.testConnection()
                    await MainActor.run {
                        url = resolvedUrl
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

        case .mqtt:
            let service = MQTTService(
                hostname: mqttHostname,
                port: UInt16(mqttPort) ?? 1883,
                username: mqttUsernamePasswordAuth ? mqttUsername : nil,
                password: mqttUsernamePasswordAuth ? mqttPassword : nil,
                enableSSL: mqttSsl,
                allowUntrustedSSL: mqttSsl && mqttUntrustedSSL,
                protocolMethod: mqttProtocolMethod,
                protocolVersion: mqttProtocolVersion,
                basePath: mqttBasePath,
                subscriptions: mqttSubscriptions
            )
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

}

#Preview("New") {
    DataSourceDetailView(dataSource: nil)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
