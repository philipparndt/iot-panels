import SwiftUI

struct InfluxDB1SetupResult {
    let url: String
    let username: String
    let password: String
    let database: String
}

struct InfluxDB1SetupView: View {
    @Environment(\.dismiss) private var dismiss

    let onComplete: (InfluxDB1SetupResult) -> Void

    enum Step: Int, CaseIterable {
        case connect = 0
        case database = 1
        case finish = 2

        var title: String {
            switch self {
            case .connect: return "Connect"
            case .database: return "Database"
            case .finish: return "Done"
            }
        }
    }

    @State private var step: Step = .connect

    // Connection
    @State private var url = ""
    @State private var useAuth = false
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    // Database
    @State private var databases: [String] = []
    @State private var selectedDatabase: String?

    // Result
    @State private var isTesting = false
    @State private var testPassed: Bool?

    @FocusState private var focusedField: ConnectField?

    private enum ConnectField: Hashable {
        case url, username, password
    }

    private var resolvedUrl: String {
        let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "http://\(trimmed)"
    }

    private var canConnect: Bool {
        !url.isEmpty && !isConnecting
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
                    case .database:
                        databaseStep
                    case .finish:
                        finishStep
                    }

                    if let errorMessage {
                        Section {
                            Label(errorMessage, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("InfluxDB 1 Setup")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { focusedField = .url }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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

    // MARK: - Steps

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
                    if useAuth {
                        focusedField = .username
                    } else if canConnect {
                        connect()
                    }
                }
        } header: {
            Text("Connection")
        } footer: {
            Text("InfluxDB 1.x typically runs on port 8086.")
        }

        Section {
            Toggle("Use Authentication", isOn: $useAuth)
            if useAuth {
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
    private var databaseStep: some View {
        Section("Select Database") {
            if databases.isEmpty {
                ProgressView("Loading databases...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(databases, id: \.self) { db in
                    Button {
                        selectedDatabase = db
                        finalize()
                    } label: {
                        HStack {
                            Text(db)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedDatabase == db {
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
        if isTesting {
            Section {
                ProgressView("Testing connection...")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else if let db = selectedDatabase {
            Section("Configuration Summary") {
                LabeledContent("Server", value: url)
                LabeledContent("Database", value: db)
                LabeledContent("Authentication", value: useAuth ? "Username/Password" : "None")
            }

            Section {
                if let testPassed {
                    if testPassed {
                        Label("Connection successful", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label(errorMessage ?? "Connection failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
            }

            if testPassed == true {
                Section {
                    Button("Finish") {
                        onComplete(InfluxDB1SetupResult(
                            url: url,
                            username: useAuth ? username : "",
                            password: useAuth ? password : "",
                            database: db
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
        let service = InfluxDB1Service(
            url: resolved,
            database: "",
            username: useAuth ? username : "",
            password: useAuth ? password : ""
        )

        Task {
            do {
                let dbs = try await service.fetchDatabases()
                await MainActor.run {
                    self.url = resolved
                    databases = dbs
                    isConnecting = false
                    if dbs.count == 1 {
                        selectedDatabase = dbs[0]
                        finalize()
                    } else {
                        step = .database
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isConnecting = false
                }
            }
        }
    }

    private func finalize() {
        step = .finish
        errorMessage = nil
        testPassed = nil
        runConnectionTest()
    }

    private func runConnectionTest() {
        guard let db = selectedDatabase else { return }
        isTesting = true
        errorMessage = nil
        testPassed = nil

        let service = InfluxDB1Service(
            url: url,
            database: db,
            username: useAuth ? username : "",
            password: useAuth ? password : ""
        )

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
