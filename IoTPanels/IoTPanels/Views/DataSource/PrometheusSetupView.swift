import SwiftUI

struct PrometheusSetupResult {
    let url: String
    let authMethod: PrometheusAuthMethod
    let token: String
    let username: String
    let password: String
}

struct PrometheusSetupView: View {
    @Environment(\.dismiss) private var dismiss

    let onComplete: (PrometheusSetupResult) -> Void

    enum Step: Int, CaseIterable {
        case connect = 0
        case finish = 1

        var title: String {
            switch self {
            case .connect: return "Connect"
            case .finish: return "Done"
            }
        }
    }

    @State private var step: Step = .connect

    // Connection
    @State private var url = ""
    @State private var authMethod: PrometheusAuthMethod = .none
    @State private var token = ""
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?

    // Testing
    @State private var isTesting = false
    @State private var testPassed: Bool?

    @FocusState private var focusedField: ConnectField?

    private enum ConnectField: Hashable {
        case url, token, username, password
    }

    private var resolvedUrl: String {
        let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "http://\(trimmed)"
    }

    private var canConnect: Bool {
        !url.isEmpty && !isTesting
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
            .navigationTitle("Prometheus Setup")
            .inlineNavigationTitle()
            .onAppear { focusedField = .url }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                    switch authMethod {
                    case .bearerToken:
                        focusedField = .token
                    case .basicAuth:
                        focusedField = .username
                    case .none:
                        if canConnect { testAndFinish() }
                    }
                }
        } header: {
            Text("Connection")
        } footer: {
            Text("Enter the Prometheus server URL (e.g., http://prometheus:9090)")
        }

        Section {
            Picker("Authentication", selection: $authMethod) {
                ForEach(PrometheusAuthMethod.allCases) { method in
                    Text(method.displayName).tag(method)
                }
            }

            switch authMethod {
            case .bearerToken:
                SecureField("Bearer Token", text: $token)
                    .focused($focusedField, equals: .token)
                    .submitLabel(.go)
                    .onSubmit { if canConnect { testAndFinish() } }
            case .basicAuth:
                TextField("Username", text: $username)
                    .focused($focusedField, equals: .username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                SecureField("Password", text: $password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canConnect { testAndFinish() } }
            case .none:
                EmptyView()
            }
        } header: {
            Text("Authentication")
        } footer: {
            switch authMethod {
            case .none:
                Text("Connect without authentication. Suitable for local installations.")
            case .bearerToken:
                Text("Use a bearer token for authenticated access.")
            case .basicAuth:
                Text("Use HTTP basic authentication.")
            }
        }

        Section {
            Button(action: testAndFinish) {
                HStack {
                    Text("Connect")
                    Spacer()
                    if isTesting {
                        ProgressView()
                    }
                }
            }
            .disabled(!canConnect)
        }
    }

    @ViewBuilder
    private var finishStep: some View {
        Section("Configuration Summary") {
            LabeledContent("Server", value: url)
            LabeledContent("Authentication", value: authMethod.displayName)
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
                    onComplete(PrometheusSetupResult(
                        url: url,
                        authMethod: authMethod,
                        token: authMethod == .bearerToken ? token : "",
                        username: authMethod == .basicAuth ? username : "",
                        password: authMethod == .basicAuth ? password : ""
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

    // MARK: - Actions

    private func testAndFinish() {
        isTesting = true
        errorMessage = nil

        let resolved = resolvedUrl
        let service = PrometheusService(
            url: resolved,
            authMethod: authMethod,
            token: authMethod == .bearerToken ? token : "",
            username: authMethod == .basicAuth ? username : "",
            password: authMethod == .basicAuth ? password : ""
        )

        Task {
            do {
                let success = try await service.testConnection()
                await MainActor.run {
                    self.url = resolved
                    isTesting = false
                    testPassed = success
                    if success {
                        step = .finish
                    } else {
                        errorMessage = "Connection refused"
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isTesting = false
                }
            }
        }
    }

    private func runConnectionTest() {
        isTesting = true
        errorMessage = nil
        testPassed = nil

        let service = PrometheusService(
            url: url,
            authMethod: authMethod,
            token: authMethod == .bearerToken ? token : "",
            username: authMethod == .basicAuth ? username : "",
            password: authMethod == .basicAuth ? password : ""
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
