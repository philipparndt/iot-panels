import SwiftUI

struct PrometheusFormView: View {
    @Binding var url: String
    @Binding var token: String
    @Binding var username: String
    @Binding var password: String
    @Binding var ssl: Bool
    @Binding var untrustedSSL: Bool

    @State private var authMethod: PrometheusAuthMethod = .none
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSuccess = false

    private var normalizedUrl: String {
        let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "http://\(trimmed)"
    }

    var body: some View {
        Form {
            Section("Connection") {
                TextField("URL", text: $url)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
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
                case .basicAuth:
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                case .none:
                    EmptyView()
                }
            } header: {
                Text("Authentication")
            }

            Section {
                Toggle("Use SSL", isOn: $ssl)
                if ssl {
                    Toggle("Allow Untrusted Certificates", isOn: $untrustedSSL)
                }
            } header: {
                Text("Security")
            }

            Section {
                Button(action: testConnection) {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        }
                    }
                }
                .disabled(url.isEmpty || isTesting)

                if let testResult {
                    Label(testResult, systemImage: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(testSuccess ? .green : .red)
                }
            }
        }
        .navigationTitle("Prometheus Settings")
        .onAppear {
            // Infer auth method from stored values
            if !token.isEmpty {
                authMethod = .bearerToken
            } else if !username.isEmpty {
                authMethod = .basicAuth
            } else {
                authMethod = .none
            }
        }
        .onChange(of: authMethod) {
            // Clear irrelevant credentials when switching auth methods
            switch authMethod {
            case .none:
                token = ""
                username = ""
                password = ""
            case .bearerToken:
                username = ""
                password = ""
            case .basicAuth:
                token = ""
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let service = PrometheusService(
            url: normalizedUrl,
            authMethod: authMethod,
            token: authMethod == .bearerToken ? token : "",
            username: authMethod == .basicAuth ? username : "",
            password: authMethod == .basicAuth ? password : ""
        )

        Task {
            do {
                let success = try await service.testConnection()
                await MainActor.run {
                    url = normalizedUrl
                    testSuccess = success
                    testResult = success ? "Connection successful" : "Connection refused"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testSuccess = false
                    testResult = error.localizedDescription
                    isTesting = false
                }
            }
        }
    }
}
