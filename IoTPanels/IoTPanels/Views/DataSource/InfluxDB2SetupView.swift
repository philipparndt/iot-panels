import SwiftUI

struct InfluxDB2SetupResult {
    let url: String
    let authMethod: InfluxAuthMethod
    let token: String
    let username: String
    let password: String
    let organization: String
    let bucket: String
}

struct InfluxDB2SetupView: View {
    @Environment(\.dismiss) private var dismiss

    let onComplete: (InfluxDB2SetupResult) -> Void

    enum Step: Int, CaseIterable {
        case connect = 0
        case organization = 1
        case bucket = 2
        case finish = 3

        var title: String {
            switch self {
            case .connect: return "Connect"
            case .organization: return "Organization"
            case .bucket: return "Bucket"
            case .finish: return "Done"
            }
        }
    }

    @State private var step: Step = .connect

    // Connection
    @State private var url = ""
    @State private var authMethod: InfluxAuthMethod = .token
    @State private var token = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    // Session (username/password flow)
    @State private var sessionService: InfluxDB2SessionService?

    // Token-based discovery service
    @State private var tokenService: InfluxDB2Service?

    // Organization
    @State private var organizations: [InfluxOrganization] = []
    @State private var selectedOrg: InfluxOrganization?

    // Bucket
    @State private var buckets: [InfluxBucket] = []
    @State private var selectedBucket: InfluxBucket?

    // Result
    @State private var createdToken: String?
    @State private var isCreatingToken = false
    @State private var isTesting = false
    @State private var testPassed: Bool?

    private var resolvedUrl: String {
        let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private var canConnect: Bool {
        guard !url.isEmpty, !isConnecting else { return false }
        switch authMethod {
        case .token:
            return !token.isEmpty
        case .usernamePassword:
            return !username.isEmpty && !password.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding()

                Form {
                    switch step {
                    case .connect:
                        connectStep
                    case .organization:
                        organizationStep
                    case .bucket:
                        bucketStep
                    case .finish:
                        finishStep
                    }

                    if let errorMessage {
                        Section {
                            Label(errorMessage, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("InfluxDB 2 Setup")
            .inlineNavigationTitle()
            .onAppear { focusedField = .url }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Task { await sessionService?.signOut() }
                        dismiss()
                    }
                }
            }
        }
        .macSheet()
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack {
            ForEach(Step.allCases, id: \.rawValue) { s in
                HStack(spacing: 4) {
                    Circle()
                        .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    if s.rawValue < Step.allCases.count - 1 {
                        Rectangle()
                            .fill(s.rawValue < step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private enum ConnectField: Hashable {
        case url, token, username, password
    }

    // MARK: - Steps

    @FocusState private var focusedField: ConnectField?

    @ViewBuilder
    private var connectStep: some View {
        Section {
            TextField("Server URL", text: $url)
                .focused($focusedField, equals: .url)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit {
                    focusedField = authMethod == .token ? .token : .username
                }
            Picker("Authentication", selection: $authMethod) {
                ForEach(InfluxAuthMethod.allCases) { method in
                    Text(method.displayName).tag(method)
                }
            }
        } header: {
            Text("Connection")
        }

        if authMethod == .token {
            Section {
                SecureField("API Token", text: $token)
                    .focused($focusedField, equals: .token)
                    .submitLabel(.go)
                    .onSubmit { if canConnect { connect() } }
            } footer: {
                Text("Enter an existing API token. Organizations and buckets will be discovered automatically.")
            }
        } else {
            Section {
                TextField("Username", text: $username)
                    .focused($focusedField, equals: .username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                SecureField("Password", text: $password)
                    .focused($focusedField, equals: .password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit { if canConnect { connect() } }
            } footer: {
                Text("Your password is only used to sign in and create an API token. It will not be stored.")
            }
        }

        Section {
            Button(action: connect) {
                HStack {
                    Text("Connect")
                    Spacer()
                    if isConnecting {
                        ProgressView()
                    }
                }
            }
            .disabled(!canConnect)
        }
    }

    @ViewBuilder
    private var organizationStep: some View {
        Section("Select Organization") {
            if organizations.isEmpty {
                ProgressView("Loading organizations...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(Array(organizations.enumerated()), id: \.element.id) { _, org in
                    Button {
                        selectedOrg = org
                        loadBuckets(orgID: org.id)
                    } label: {
                        HStack {
                            Text(org.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedOrg?.id == org.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bucketStep: some View {
        Section("Select Bucket") {
            if buckets.isEmpty {
                ProgressView("Loading buckets...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(Array(buckets.enumerated()), id: \.element.id) { _, bucket in
                    Button {
                        selectedBucket = bucket
                        finalize()
                    } label: {
                        HStack {
                            Text(bucket.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedBucket?.id == bucket.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var finishStep: some View {
        if isCreatingToken {
            Section {
                ProgressView("Creating API token...")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else if isTesting {
            Section {
                ProgressView("Testing connection...")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else if let org = selectedOrg, let bucket = selectedBucket {
            Section("Configuration Summary") {
                LabeledContent("Server", value: url)
                LabeledContent("Organization", value: org.name)
                LabeledContent("Bucket", value: bucket.name)
            }

            Section {
                if let testPassed {
                    if testPassed {
                        Label("Connection successful", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label(errorMessage ?? "Connection failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }

            if testPassed == true {
                Section {
                    Button("Finish") {
                        Task { await sessionService?.signOut() }
                        onComplete(InfluxDB2SetupResult(
                            url: url,
                            authMethod: authMethod,
                            token: authMethod == .token ? token : (createdToken ?? ""),
                            username: authMethod == .usernamePassword ? username : "",
                            password: authMethod == .usernamePassword ? password : "",
                            organization: org.name,
                            bucket: bucket.name
                        ))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Section {
                    Button("Retry") {
                        runConnectionTest()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func connect() {
        isConnecting = true
        errorMessage = nil

        let resolved = resolvedUrl

        if authMethod == .token {
            let service = InfluxDB2Service(url: resolved, token: token, organization: "", bucket: "")
            Task {
                do {
                    let orgs = try await service.fetchOrganizations()
                    await MainActor.run {
                        self.url = resolved
                        tokenService = service
                        organizations = orgs
                        isConnecting = false
                        if orgs.count == 1 {
                            selectedOrg = orgs[0]
                            step = .organization
                            loadBuckets(orgID: orgs[0].id, service: service)
                        } else {
                            step = .organization
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isConnecting = false
                    }
                }
            }
        } else {
            let service = InfluxDB2SessionService(url: resolved)
            Task {
                do {
                    try await service.signIn(username: username, password: password)
                    let orgs = try await service.fetchOrganizations()
                    await MainActor.run {
                        self.url = resolved
                        sessionService = service
                        organizations = orgs
                        isConnecting = false
                        if orgs.count == 1 {
                            selectedOrg = orgs[0]
                            step = .organization
                            loadBuckets(orgID: orgs[0].id, session: service)
                        } else {
                            step = .organization
                        }
                    }
                } catch {
                    print("InfluxDB sign-in error: \(error)")
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isConnecting = false
                    }
                }
            }
        }
    }

    private func loadBuckets(orgID: String, service: InfluxDB2Service? = nil, session: InfluxDB2SessionService? = nil) {
        errorMessage = nil
        step = .bucket
        buckets = []

        let tokenSvc = service ?? tokenService
        let sessionSvc = session ?? sessionService

        Task {
            do {
                let result: [InfluxBucket]
                if authMethod == .token, let svc = tokenSvc {
                    result = try await svc.fetchBuckets(orgID: orgID)
                } else {
                    result = try await sessionSvc?.fetchBuckets(orgID: orgID) ?? []
                }
                await MainActor.run {
                    buckets = result
                    if result.count == 1 {
                        selectedBucket = result[0]
                        finalize()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func finalize() {
        step = .finish
        errorMessage = nil
        testPassed = nil

        if authMethod == .token {
            runConnectionTest()
        } else {
            createTokenThenTest()
        }
    }

    private func createTokenThenTest() {
        guard let org = selectedOrg, let bucket = selectedBucket else { return }
        isCreatingToken = true

        Task {
            do {
                let token = try await sessionService?.createToken(
                    orgID: org.id,
                    orgName: org.name,
                    bucketID: bucket.id,
                    bucketName: bucket.name,
                    description: "IoT Panels - \(bucket.name)"
                )
                await MainActor.run {
                    createdToken = token
                    isCreatingToken = false
                    runConnectionTest()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreatingToken = false
                    testPassed = false
                }
            }
        }
    }

    private func runConnectionTest() {
        guard let org = selectedOrg, let bucket = selectedBucket else { return }
        isTesting = true
        errorMessage = nil
        testPassed = nil

        let finalToken = authMethod == .token ? token : (createdToken ?? "")
        let service = InfluxDB2Service(url: url, token: finalToken, organization: org.name, bucket: bucket.name)

        Task {
            do {
                let success = try await service.testConnection()
                await MainActor.run {
                    testPassed = success
                    isTesting = false
                    if !success {
                        errorMessage = "Connection refused"
                    }
                }
            } catch {
                await MainActor.run {
                    testPassed = false
                    errorMessage = error.localizedDescription
                    isTesting = false
                }
            }
        }
    }
}
