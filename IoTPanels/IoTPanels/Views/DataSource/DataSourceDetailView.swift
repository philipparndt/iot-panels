import SwiftUI
import CoreData

struct DataSourceDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationState.self) private var navigationState

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

    // InfluxDB 3 fields
    @State private var influx3Database = ""

    // Prometheus fields
    @State private var prometheusUrl = ""
    @State private var prometheusToken = ""
    @State private var prometheusUsername = ""
    @State private var prometheusPassword = ""
    @State private var prometheusSsl = false
    @State private var prometheusUntrustedSSL = false

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
    @State private var mqttBaseTopic = ""

    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var showingGuidedSetup = false
    @State private var showingMQTTSetup = false
    @State private var showingInflux1Setup = false
    @State private var showingInflux3Setup = false
    @State private var showingPrometheusSetup = false
    @State private var shareFileURL: URL?
    @State private var showShareSheet = false
    @State private var didLoad = false
    @State private var showingQueries = false
    @FocusState private var nameFieldFocused: Bool

    enum TestResult {
        case success
        case failure(String)
    }

    var isEditing: Bool { dataSource != nil }

    private var canSave: Bool {
        switch backendType {
        case .influxDB1:
            return !url.isEmpty
        case .influxDB2:
            guard !url.isEmpty else { return false }
            switch influxAuthMethod {
            case .token:
                return isEditing || !token.isEmpty
            case .usernamePassword:
                return !influxUsername.isEmpty && (isEditing || !influxPassword.isEmpty)
            }
        case .influxDB3:
            return !url.isEmpty
        case .prometheus:
            return !prometheusUrl.isEmpty
        case .mqtt:
            return !mqttHostname.isEmpty
        case .demo:
            return true
        }
    }

    private var canTest: Bool {
        guard !isTesting else { return false }
        switch backendType {
        case .influxDB1:
            return !url.isEmpty
        case .influxDB2:
            guard !url.isEmpty else { return false }
            switch influxAuthMethod {
            case .token:
                return !token.isEmpty
            case .usernamePassword:
                return !influxUsername.isEmpty && !influxPassword.isEmpty
            }
        case .influxDB3:
            return !url.isEmpty
        case .prometheus:
            return !prometheusUrl.isEmpty
        case .mqtt:
            return !mqttHostname.isEmpty
        case .demo:
            return true
        }
    }

    var body: some View {
        let form = Form {
            Section("General") {
                Picker("Type", selection: $backendType) {
                    ForEach(BackendType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .accessibilityIdentifier("backendTypePicker")
                TextField("Name", text: $name)
            }

            if backendType == .demo {
                Section {
                    Label("This data source generates realistic demo data for testing. No network connection required.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if backendType == .influxDB1 && !isEditing {
                Section {
                    Button {
                        showingInflux1Setup = true
                    } label: {
                        Label("Setup Wizard", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Guided Setup")
                } footer: {
                    Text("Connect to your InfluxDB 1.x server and select a database.")
                }
            }

            if backendType == .influxDB1 {
                Section("InfluxDB 1") {
                    NavigationLink {
                        InfluxDB1SettingsFormView(
                            url: $url,
                            username: $influxUsername,
                            password: $influxPassword,
                            database: $influx3Database
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

            if backendType == .prometheus && !isEditing {
                Section {
                    Button {
                        showingPrometheusSetup = true
                    } label: {
                        Label("Setup Wizard", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Guided Setup")
                } footer: {
                    Text("Connect to your Prometheus server and test the connection.")
                }
            }

            if backendType == .prometheus {
                Section("Prometheus") {
                    NavigationLink {
                        PrometheusFormView(
                            url: $prometheusUrl,
                            token: $prometheusToken,
                            username: $prometheusUsername,
                            password: $prometheusPassword,
                            ssl: $prometheusSsl,
                            untrustedSSL: $prometheusUntrustedSSL
                        )
                    } label: {
                        HStack {
                            Label("Connection Settings", systemImage: "server.rack")
                            Spacer()
                            if !prometheusUrl.isEmpty {
                                Text(prometheusUrl.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            if backendType == .mqtt && !isEditing {
                Section {
                    Button {
                        showingMQTTSetup = true
                    } label: {
                        Label("Setup Wizard", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Guided Setup")
                } footer: {
                    Text("Configure how to authenticate with the broker.")
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

            if backendType == .influxDB3 && !isEditing {
                Section {
                    Button {
                        showingInflux3Setup = true
                    } label: {
                        Label("Setup Wizard", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Guided Setup")
                } footer: {
                    Text("Connect to your InfluxDB 3 server and select a database.")
                }
            }

            if backendType == .influxDB3 {
                Section("InfluxDB 3") {
                    NavigationLink {
                        InfluxDB3SettingsFormView(
                            url: $url,
                            token: $token,
                            database: $influx3Database
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
                            baseTopic: $mqttBaseTopic
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
                    #if os(macOS)
                    Button {
                        showingQueries = true
                    } label: {
                        Label("Queries", systemImage: "magnifyingglass")
                    }
                    #else
                    NavigationLink {
                        SavedQueryListView(dataSource: dataSource)
                    } label: {
                        Label("Queries", systemImage: "magnifyingglass")
                    }
                    #endif
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
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .sheet(isPresented: $showingInflux1Setup) {
            InfluxDB1SetupView { result in
                url = result.url
                influxUsername = result.username
                influxPassword = result.password
                influx3Database = result.database
                showingInflux1Setup = false
                if name.isEmpty {
                    name = result.database
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
        .sheet(isPresented: $showingInflux3Setup) {
            InfluxDB3SetupView { result in
                url = result.url
                token = result.token
                influx3Database = result.database
                showingInflux3Setup = false
                if name.isEmpty {
                    name = result.database
                }
            }
        }
        .sheet(isPresented: $showingPrometheusSetup) {
            PrometheusSetupView { result in
                prometheusUrl = result.url
                prometheusToken = result.authMethod == .bearerToken ? result.token : ""
                prometheusUsername = result.authMethod == .basicAuth ? result.username : ""
                prometheusPassword = result.authMethod == .basicAuth ? result.password : ""
                showingPrometheusSetup = false
                if name.isEmpty {
                    name = "Prometheus"
                }
            }
        }
        .sheet(isPresented: $showingMQTTSetup) {
            MQTTSetupView { result in
                mqttHostname = result.hostname
                mqttPort = result.port
                mqttProtocolMethod = result.protocolMethod
                mqttProtocolVersion = result.protocolVersion
                mqttBasePath = result.basePath
                mqttSsl = result.ssl
                mqttUntrustedSSL = result.untrustedSSL
                mqttCertServerCA = result.certServerCA
                mqttAlpn = result.alpn
                mqttUsernamePasswordAuth = result.usernamePasswordAuth
                mqttUsername = result.username
                mqttPassword = result.password
                mqttCertificateAuth = result.certificateAuth
                mqttCertP12 = result.certP12
                mqttCertClientKeyPassword = result.certClientKeyPassword
                mqttClientID = result.clientID
                mqttBaseTopic = result.baseTopic
                showingMQTTSetup = false
                if name.isEmpty {
                    name = result.hostname
                }
            }
        }

        .sheet(isPresented: $showingQueries) {
            if let dataSource {
                NavigationStack {
                    SavedQueryListView(dataSource: dataSource)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingQueries = false }
                            }
                        }
                }
                .frame(minWidth: 500, minHeight: 400)
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
                #if os(iOS)
                .sheet(isPresented: $showShareSheet) {
                    if let url = shareFileURL {
                        ShareSheetView(activityItems: [url])
                    }
                }
                #else
                .onChange(of: showShareSheet) { _, newValue in
                    if newValue, let url = shareFileURL {
                        MacFileExporter.revealOrExport(url: url)
                        showShareSheet = false
                    }
                }
                #endif
                .onAppear(perform: loadDataSource)
                .onDisappear { persistFields() }
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
                    .onAppear { }
            }
            .macSheet()
        }
    }

    private func loadDataSource() {
        guard !didLoad, let dataSource else { return }
        didLoad = true
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

        // InfluxDB 3
        influx3Database = dataSource.wrappedDatabase

        // Prometheus
        if backendType == .prometheus {
            prometheusUrl = dataSource.wrappedUrl
            prometheusToken = dataSource.wrappedToken
            prometheusUsername = dataSource.wrappedUsername
            prometheusPassword = dataSource.wrappedPassword
            prometheusSsl = dataSource.wrappedSsl
            prometheusUntrustedSSL = dataSource.wrappedUntrustedSSL
        }

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
        mqttBaseTopic = dataSource.wrappedMqttBaseTopic
    }

    private func persistFields() {
        let target = dataSource ?? DataSource(context: viewContext)

        if dataSource == nil {
            target.id = UUID()
            target.createdAt = Date()
            target.home = navigationState.selectedHome
        }

        target.name = name.isEmpty ? backendType.displayName : name
        target.backendType = backendType.rawValue
        target.modifiedAt = Date()

        // InfluxDB fields
        if backendType == .prometheus {
            target.url = prometheusUrl
            target.token = prometheusToken.isEmpty ? nil : prometheusToken
            target.ssl = prometheusSsl
            target.untrustedSSL = prometheusSsl && prometheusUntrustedSSL
        } else {
            target.url = url
            target.ssl = mqttSsl
            target.untrustedSSL = mqttSsl && mqttUntrustedSSL
        }
        target.influxAuthMethod = influxAuthMethod.rawValue
        if backendType == .influxDB3 {
            target.token = token
        } else if backendType != .prometheus {
            target.token = influxAuthMethod == .token ? token : nil
        }
        target.organization = organization
        target.bucket = bucket
        target.database = influx3Database

        // MQTT fields
        target.hostname = mqttHostname
        target.port = Int32(mqttPort) ?? 1883
        target.protocolMethod = mqttProtocolMethod.rawValue
        target.protocolVersion = mqttProtocolVersion.rawValue
        target.basePath = mqttBasePath
        if backendType != .prometheus {
            target.ssl = mqttSsl
            target.untrustedSSL = mqttSsl && mqttUntrustedSSL
        }
        target.wrappedAlpn = mqttAlpn
        if backendType == .influxDB1 {
            target.username = influxUsername.isEmpty ? nil : influxUsername
            target.password = influxPassword.isEmpty ? nil : influxPassword
        } else if backendType == .influxDB2 && influxAuthMethod == .usernamePassword {
            target.username = influxUsername
            target.password = influxPassword
        } else if backendType == .prometheus {
            target.username = prometheusUsername.isEmpty ? nil : prometheusUsername
            target.password = prometheusPassword.isEmpty ? nil : prometheusPassword
        } else {
            target.username = mqttUsernamePasswordAuth ? mqttUsername : nil
            target.password = mqttUsernamePasswordAuth ? mqttPassword : nil
        }
        target.clientID = mqttClientID.isEmpty ? nil : mqttClientID
        target.certClientKeyPassword = mqttCertificateAuth ? mqttCertClientKeyPassword : nil
        target.mqttBaseTopic = mqttBaseTopic.trimmingCharacters(in: .whitespaces)

        // Build certificates array from individual pickers
        var certs: [MQTTCertificateFile] = []
        if let serverCA = mqttCertServerCA { certs.append(serverCA) }
        if mqttCertificateAuth, let p12 = mqttCertP12 { certs.append(p12) }
        target.wrappedCertificates = certs

        try? viewContext.save()
    }

    private func save() {
        persistFields()
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

        case .influxDB1:
            let resolvedUrl = normalizedInfluxUrl()
            let influx1Service = InfluxDB1Service(url: resolvedUrl, database: influx3Database, username: influxUsername, password: influxPassword)
            Task {
                do {
                    let success = try await influx1Service.testConnection()
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

        case .influxDB3:
            let resolvedUrl = normalizedInfluxUrl()
            let influx3Service = InfluxDB3Service(url: resolvedUrl, token: token, database: influx3Database)
            Task {
                do {
                    let success = try await influx3Service.testConnection()
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

        case .prometheus:
            let resolvedUrl = {
                let trimmed = prometheusUrl.hasSuffix("/") ? String(prometheusUrl.dropLast()) : prometheusUrl
                if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                    return trimmed
                }
                return "http://\(trimmed)"
            }()
            let promService = PrometheusService(
                url: resolvedUrl,
                authMethod: !prometheusToken.isEmpty ? .bearerToken : (!prometheusUsername.isEmpty ? .basicAuth : .none),
                token: prometheusToken,
                username: prometheusUsername,
                password: prometheusPassword
            )
            Task {
                do {
                    let success = try await promService.testConnection()
                    await MainActor.run {
                        prometheusUrl = resolvedUrl
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
            var certs: [MQTTCertificateFile] = []
            if let serverCA = mqttCertServerCA { certs.append(serverCA) }
            if mqttCertificateAuth, let p12 = mqttCertP12 { certs.append(p12) }
            let service = MQTTService(
                hostname: mqttHostname,
                port: UInt16(mqttPort) ?? 1883,
                clientID: mqttClientID,
                username: mqttUsernamePasswordAuth ? mqttUsername : nil,
                password: mqttUsernamePasswordAuth ? mqttPassword : nil,
                enableSSL: mqttSsl,
                allowUntrustedSSL: mqttSsl && mqttUntrustedSSL,
                alpn: mqttAlpn.isEmpty ? nil : mqttAlpn,
                protocolMethod: mqttProtocolMethod,
                protocolVersion: mqttProtocolVersion,
                basePath: mqttBasePath,
                certificates: certs,
                certPassword: mqttCertificateAuth ? mqttCertClientKeyPassword : ""
            )
            Task {
                do {
                    let success = try await service.testConnection()
                    await MainActor.run {
                        testResult = success ? .success : .failure("Connection refused")
                        isTesting = false
                        if success {
                            // Establish the persistent connection so the banner
                            // clears and dashboard panels receive data immediately.
                            MQTTConnectionManager.shared.ensureConnected(for: service)
                        }
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
