import SwiftUI

struct MQTTSetupResult {
    let hostname: String
    let port: String
    let protocolMethod: MQTTProtocolMethod
    let protocolVersion: MQTTProtocolVersion
    let basePath: String
    let ssl: Bool
    let untrustedSSL: Bool
    let certServerCA: MQTTCertificateFile?
    let alpn: String
    let usernamePasswordAuth: Bool
    let username: String
    let password: String
    let certificateAuth: Bool
    let certP12: MQTTCertificateFile?
    let certClientKeyPassword: String
    let clientID: String
    let baseTopic: String
}

struct MQTTSetupView: View {
    @Environment(\.dismiss) private var dismiss

    let onComplete: (MQTTSetupResult) -> Void

    // Connection
    @State private var hostname = ""
    @State private var port = "1883"
    @State private var protocolMethod: MQTTProtocolMethod = .mqtt
    @State private var protocolVersion: MQTTProtocolVersion = .mqtt3
    @State private var basePath = ""
    @State private var ssl = false

    // TLS
    @State private var untrustedSSL = false
    @State private var certServerCA: MQTTCertificateFile?
    @State private var alpn = ""

    // Auth
    @State private var usernamePasswordAuth = false
    @State private var username = ""
    @State private var password = ""
    @State private var certificateAuth = false
    @State private var certP12: MQTTCertificateFile?
    @State private var certClientKeyPassword = ""
    @State private var showCertificateHelp = false

    // Discovery & Advanced
    @State private var baseTopic = ""
    @State private var clientID = ""
    @State private var showAdvanced = false

    // Test
    @State private var isTesting = false
    @State private var testPassed: Bool?
    @State private var testError: String?

    var body: some View {
        NavigationStack {
            Form {
                // Server
                serverSection

                // TLS details (if enabled)
                if ssl {
                    MQTTTLSFormView(
                        ssl: $ssl,
                        untrustedSSL: $untrustedSSL,
                        certServerCA: $certServerCA,
                        alpn: $alpn
                    )
                }

                // Authentication
                MQTTAuthFormView(
                    usernamePasswordAuth: $usernamePasswordAuth,
                    username: $username,
                    password: $password,
                    certificateAuth: $certificateAuth,
                    certP12: $certP12,
                    certClientKeyPassword: $certClientKeyPassword,
                    showCertificateHelp: $showCertificateHelp
                )

                // Discovery
                Section {
                    HStack {
                        Text("Base Topic")
                        Spacer()
                        TextField("e.g. home/#", text: $baseTopic)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("Discovery")
                } footer: {
                    Text("Used to discover topics when creating queries. Leave empty to subscribe to all topics (#).")
                }

                // Advanced
                Toggle(isOn: $showAdvanced) {
                    Text("More settings")
                        .font(.headline)
                }
                if showAdvanced {
                    MQTTClientIDFormView(clientID: $clientID)
                }

                // Test & Finish
                testSection
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("MQTT Setup")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .macSheet()
    }

    // MARK: - Server Section

    private var serverSection: some View {
        Section("Connection") {
            HStack {
                Text("Hostname")
                    .font(.headline)
                Spacer()
                TextField("ip address / name", text: $hostname)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Toggle("Enable TLS", isOn: $ssl)

            HStack {
                Text("Port")
                    .font(.headline)
                Spacer()
                TextField("e.g. 1883", text: $port)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
            }

            Picker("Protocol", selection: $protocolMethod) {
                Text("MQTT").tag(MQTTProtocolMethod.mqtt)
                Text("WebSocket").tag(MQTTProtocolMethod.websocket)
            }

            Picker("Version", selection: $protocolVersion) {
                Text("3.1.1").tag(MQTTProtocolVersion.mqtt3)
                Text("5.0").tag(MQTTProtocolVersion.mqtt5)
            }

            if protocolMethod == .websocket {
                HStack {
                    Text("Basepath")
                    Spacer()
                    TextField("/", text: $basePath)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }

            // Port hints
            HStack(spacing: 8) {
                Text("Common ports:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(suggestedPorts, id: \.port) { item in
                    Button {
                        port = item.port
                    } label: {
                        Text("\(item.port) (\(item.label))")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
    }

    private var suggestedPorts: [(port: String, label: String)] {
        switch (protocolMethod, ssl) {
        case (.mqtt, false): return [("1883", "MQTT")]
        case (.mqtt, true): return [("8883", "MQTTS"), ("443", "SNI")]
        case (.websocket, false): return [("80", "HTTP"), ("8080", "Alt")]
        case (.websocket, true): return [("443", "HTTPS")]
        }
    }

    // MARK: - Test & Finish

    private var testSection: some View {
        Section {
            if isTesting {
                HStack {
                    ProgressView()
                    Text("Testing connection...")
                        .foregroundStyle(.secondary)
                }
            } else if let passed = testPassed {
                if passed {
                    Label("Connection successful", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(testError ?? "Connection failed", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            Button {
                runTest()
            } label: {
                Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
            }
            .disabled(hostname.isEmpty || isTesting)

            Button {
                onComplete(MQTTSetupResult(
                    hostname: hostname,
                    port: port,
                    protocolMethod: protocolMethod,
                    protocolVersion: protocolVersion,
                    basePath: basePath,
                    ssl: ssl,
                    untrustedSSL: untrustedSSL,
                    certServerCA: certServerCA,
                    alpn: alpn,
                    usernamePasswordAuth: usernamePasswordAuth,
                    username: username,
                    password: password,
                    certificateAuth: certificateAuth,
                    certP12: certP12,
                    certClientKeyPassword: certClientKeyPassword,
                    clientID: clientID,
                    baseTopic: baseTopic
                ))
                dismiss()
            } label: {
                Label("Finish", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
            .disabled(hostname.isEmpty)
        }
    }

    // MARK: - Test

    private func runTest() {
        isTesting = true
        testPassed = nil
        testError = nil

        #if canImport(CocoaMQTT)
        var certs: [MQTTCertificateFile] = []
        if let serverCA = certServerCA { certs.append(serverCA) }
        if certificateAuth, let p12 = certP12 { certs.append(p12) }

        let service = MQTTService(
            hostname: hostname,
            port: UInt16(port) ?? 1883,
            clientID: clientID,
            username: usernamePasswordAuth ? username : nil,
            password: usernamePasswordAuth ? password : nil,
            enableSSL: ssl,
            allowUntrustedSSL: ssl && untrustedSSL,
            protocolMethod: protocolMethod,
            protocolVersion: protocolVersion,
            basePath: basePath,
            certificates: certs,
            certPassword: certificateAuth ? certClientKeyPassword : ""
        )
        Task {
            do {
                let success = try await service.testConnection()
                await MainActor.run {
                    testPassed = success
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testPassed = false
                    testError = error.localizedDescription
                    isTesting = false
                }
            }
        }
        #else
        isTesting = false
        testPassed = false
        testError = "MQTT not available"
        #endif
    }
}
