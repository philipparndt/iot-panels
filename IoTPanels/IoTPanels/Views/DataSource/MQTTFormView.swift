import SwiftUI
import UniformTypeIdentifiers

// MARK: - Server Section

struct MQTTServerFormView: View {
    @Binding var hostname: String
    @Binding var port: String
    @Binding var protocolMethod: MQTTProtocolMethod
    @Binding var protocolVersion: MQTTProtocolVersion
    @Binding var basePath: String
    @Binding var ssl: Bool

    private var hostnameInvalid: Bool {
        !hostname.isEmpty && hostname.contains(" ")
    }

    private var portInvalid: Bool {
        Int(port) == nil || Int(port)! < 1 || Int(port)! > 65535
    }

    private var suggestedPorts: [(port: String, label: String)] {
        switch (protocolMethod, ssl) {
        case (.mqtt, false):
            return [("1883", "MQTT")]
        case (.mqtt, true):
            return [("8883", "MQTTS"), ("443", "SNI/ALPN")]
        case (.websocket, false):
            return [("80", "HTTP"), ("8080", "Alt")]
        case (.websocket, true):
            return [("443", "HTTPS")]
        }
    }

    var body: some View {
        Section(header: Text("Server")) {
            HStack {
                if hostnameInvalid {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.headline)
                        .foregroundColor(.red)
                }

                Text("Hostname")
                    .font(.headline)

                Spacer()

                TextField("", text: $hostname, prompt: Text("ip address / name").foregroundColor(.secondary))
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if portInvalid {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                    }

                    Text("Port")
                        .font(.headline)

                    Spacer()

                    TextField("", text: $port, prompt: Text("e.g. 1883").foregroundColor(.secondary))
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .font(.body)
                        .keyboardType(.numberPad)
                }

                HStack(spacing: 8) {
                    Text("Common ports:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(suggestedPorts, id: \.port) { suggestion in
                        Button {
                            port = suggestion.port
                        } label: {
                            Text(suggestion.port)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(port == suggestion.port ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(port == suggestion.port ? .white : .primary)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Text("Protocol")
                    .font(.headline)
                    .frame(minWidth: 100, alignment: .leading)

                Spacer()

                Picker("Protocol", selection: $protocolMethod) {
                    ForEach(MQTTProtocolMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            HStack {
                Text("Version")
                    .font(.headline)
                    .frame(minWidth: 100, alignment: .leading)

                Spacer()

                Picker("Version", selection: $protocolVersion) {
                    ForEach(MQTTProtocolVersion.allCases) { version in
                        Text(version.displayName).tag(version)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            if protocolMethod == .websocket {
                HStack {
                    Text("Basepath")
                        .font(.headline)

                    Spacer()

                    TextField("", text: $basePath, prompt: Text("/").foregroundColor(.secondary))
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.body)
                }
            }
        }
    }
}

// MARK: - TLS Section

struct MQTTTLSFormView: View {
    @Binding var ssl: Bool
    @Binding var untrustedSSL: Bool
    @Binding var certServerCA: MQTTCertificateFile?
    @Binding var alpn: String

    var body: some View {
        Section(header: Text("TLS"), footer: tlsFooter) {
            Toggle(isOn: $ssl) {
                Text("Enable TLS")
                    .font(.headline)
            }

            if ssl {
                Toggle(isOn: $untrustedSSL) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow untrusted")
                            .font(.headline)
                        Text("Skip certificate validation (insecure)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if untrustedSSL {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.shield")
                            .foregroundColor(.orange)
                        Text("Certificate validation disabled - connection may be insecure")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if !untrustedSSL {
                    VStack(alignment: .leading, spacing: 8) {
                        MQTTCertificatePickerView(
                            label: "Server CA",
                            file: $certServerCA,
                            type: .serverCA
                        )

                        if certServerCA == nil {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.shield")
                                        .foregroundColor(.green)
                                    Text("Using system trusted CAs")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("The server certificate will be validated against the system's trusted certificate authorities. Add a custom CA for self-signed or private CA certificates.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundColor(.blue)
                                Text("Using custom CA for validation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ALPN")
                            .font(.headline)

                        Spacer()

                        TextField("", text: $alpn, prompt: Text("e.g. mqtt").foregroundColor(.secondary))
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.body)
                    }

                    Text("Application-Layer Protocol Negotiation. Used when sharing port 443 with HTTPS.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var tlsFooter: some View {
        if !ssl {
            Text("Enable TLS to encrypt the connection to the broker.")
                .font(.caption)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Authentication Section

struct MQTTAuthFormView: View {
    @Binding var usernamePasswordAuth: Bool
    @Binding var username: String
    @Binding var password: String
    @Binding var certificateAuth: Bool
    @Binding var certP12: MQTTCertificateFile?
    @Binding var certClientKeyPassword: String
    @Binding var showCertificateHelp: Bool

    var body: some View {
        Section(header: Text("Authentication"), footer: authFooter) {
            Toggle(isOn: $usernamePasswordAuth) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Username/Password")
                        .font(.headline)
                    Text("Authenticate with credentials")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if usernamePasswordAuth {
                HStack {
                    Text("Username")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("", text: $username)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.body)
                }

                HStack {
                    Text("Password")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    SecureField("", text: $password)
                        .multilineTextAlignment(.trailing)
                        .font(.body)
                }
            }

            Toggle(isOn: $certificateAuth) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Client Certificate (mTLS)")
                        .font(.headline)
                    Text("Authenticate with a client certificate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if certificateAuth {
                MQTTCertificatePickerView(
                    label: "Client PKCS#12",
                    file: $certP12,
                    type: .p12
                )

                HStack {
                    Text("Password")
                        .font(.headline)

                    Spacer()

                    SecureField("", text: $certClientKeyPassword, prompt: Text("Certificate password").foregroundColor(.secondary))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                        .font(.body)
                }

                if certP12 != nil && certClientKeyPassword.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Password is required for PKCS#12 files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if certP12 == nil {
                    Text("Client certificate for mTLS authentication")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button {
                    showCertificateHelp = true
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("How to create certificates")
                    }
                    .foregroundColor(.accentColor)
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var authFooter: some View {
        if !usernamePasswordAuth && !certificateAuth {
            Text("Configure how to authenticate with the broker.")
                .font(.caption)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Subscriptions Section

struct MQTTSubscriptionsFormView: View {
    @Binding var subscriptions: [MQTTTopicSubscription]

    var body: some View {
        Section(header: Text("Subscribe to")) {
            ForEach($subscriptions) { $subscription in
                NavigationLink {
                    MQTTSubscriptionDetailView(subscription: $subscription) {
                        subscriptions.removeAll { $0.id == subscription.id }
                    }
                } label: {
                    Text(subscription.topic.isEmpty ? "(empty)" : subscription.topic)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        subscriptions.removeAll { $0.id == subscription.id }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                subscriptions.remove(atOffsets: offsets)
            }

            Button {
                subscriptions.append(MQTTTopicSubscription(topic: "", qos: 0))
            } label: {
                Text("Add subscription")
            }
        }
    }
}

// MARK: - Subscription Detail View (subpage)

struct MQTTSubscriptionDetailView: View {
    @Binding var subscription: MQTTTopicSubscription
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTopicFocused: Bool

    @State private var topic: String = ""
    @State private var qos: Int = 0

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Topic")
                        .font(.headline)

                    Spacer()

                    TextField("", text: $topic, prompt: Text("e.g. home/#").foregroundColor(.secondary))
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.body)
                        .focused($isTopicFocused)
                }
            } footer: {
                MQTTTopicFilterHelpView()
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("QoS")
                            .font(.headline)

                        Spacer()

                        Picker("QoS", selection: $qos) {
                            Text("0").tag(0)
                            Text("1").tag(1)
                            Text("2").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 150)
                    }

                    MQTTQoSDescriptionView(qos: qos)
                        .padding(.top, 4)
                }
            } footer: {
                Text("Quality of Service determines message delivery guarantees")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    dismiss()
                    onDelete()
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete")
                        Spacer()
                    }
                }
            }
        }
        .inlineNavigationTitle()
        .navigationTitle("Subscription")
        .onAppear {
            topic = subscription.topic
            qos = subscription.qos
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTopicFocused = true
            }
        }
        .onDisappear {
            subscription.topic = topic
            subscription.qos = qos
        }
    }
}

// MARK: - Topic Filter Help

struct MQTTTopicFilterHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wildcards")
                .font(.caption)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text("#")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(width: 24, alignment: .leading)
                    Text("Multi-level: matches any number of levels")
                        .font(.caption)
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("+")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(width: 24, alignment: .leading)
                    Text("Single-level: matches exactly one level")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)

            Text("Examples")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                topicExample("home/#", description: "All topics under home/")
                topicExample("sensor/+/temp", description: "Temperature from any sensor")
                topicExample("#", description: "All topics (use with caution)")
            }
        }
        .padding(.top, 4)
    }

    private func topicExample(_ topic: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(topic)
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 100, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - QoS Description

struct MQTTQoSDescriptionView: View {
    let qos: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch qos {
            case 0:
                Text("At most once")
                    .font(.caption.weight(.semibold))
                Text("Messages are delivered at most once. No acknowledgement. Fastest but may lose messages.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case 1:
                Text("At least once")
                    .font(.caption.weight(.semibold))
                Text("Messages are delivered at least once. Acknowledged by receiver. May cause duplicates.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case 2:
                Text("Exactly once")
                    .font(.caption.weight(.semibold))
                Text("Messages are delivered exactly once. Four-step handshake. Slowest but most reliable.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Client ID Section

struct MQTTClientIDFormView: View {
    @Binding var clientID: String

    var body: some View {
        Section(header: Text("Client ID")) {
            HStack {
                Text("Client ID")
                    .font(.headline)

                Spacer()

                TextField("", text: $clientID, prompt: Text("Random by default").foregroundColor(.secondary))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
                    .font(.body)
            }
        }
    }
}

// MARK: - Certificate Picker

struct MQTTCertificatePickerView: View {
    let label: String
    @Binding var file: MQTTCertificateFile?
    let type: MQTTCertificateFileType

    @State private var showFilePicker = false
    @State private var showStorageChoice = false
    @State private var pendingFileURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.headline)

                Spacer()

                if let selectedFile = file {
                    selectedFileView(selectedFile)
                } else {
                    selectButton
                }
            }

            if let selectedFile = file, selectedFile.fileURL != nil,
               !FileManager.default.fileExists(atPath: selectedFile.fileURL!.path) {
                missingFileWarning
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImportResult(result)
        }
        .confirmationDialog(
            "Where should this certificate be stored?",
            isPresented: $showStorageChoice,
            titleVisibility: .visible
        ) {
            Button("This Device Only") {
                if let url = pendingFileURL {
                    completeImport(url: url, location: .local)
                }
            }
            Button("iCloud (sync to all devices)") {
                if let url = pendingFileURL {
                    completeImport(url: url, location: .cloud)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingFileURL = nil
            }
        } message: {
            Text("Local is more secure for certificates with private keys. iCloud syncs across devices but stores the private key in the cloud.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private var selectButton: some View {
        Button {
            showFilePicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.badge.plus")
                Text("Select")
            }
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
    }

    private func selectedFileView(_ selectedFile: MQTTCertificateFile) -> some View {
        HStack(spacing: 8) {
            Image(systemName: selectedFile.location == .cloud ? "icloud.fill" : "doc.fill")
                .foregroundColor(selectedFile.location == .cloud ? .blue : .accentColor)

            Text(selectedFile.name)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Button {
                file = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var missingFileWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Certificate not available on this device")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import Certificate")
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    private var allowedTypes: [UTType] {
        switch type {
        case .p12:
            var types: [UTType] = [.pkcs12]
            if let pfx = UTType(filenameExtension: "pfx") { types.append(pfx) }
            return types
        case .serverCA, .client:
            var types: [UTType] = [.x509Certificate]
            if let crt = UTType(filenameExtension: "crt") { types.append(crt) }
            if let pem = UTType(filenameExtension: "pem") { types.append(pem) }
            if type == .serverCA {
                types.append(.pkcs12)
                if let pfx = UTType(filenameExtension: "pfx") { types.append(pfx) }
            }
            return types
        case .clientKey:
            var types: [UTType] = []
            if let key = UTType(filenameExtension: "key") { types.append(key) }
            if let pem = UTType(filenameExtension: "pem") { types.append(pem) }
            return types.isEmpty ? [.data] : types
        case .undefined:
            return [.pkcs12, .x509Certificate]
        }
    }

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access the selected file"
                showError = true
                return
            }

            if type == .serverCA {
                // Server CA always uses iCloud
                completeImport(url: url, location: .cloud)
            } else {
                pendingFileURL = url
                showStorageChoice = true
            }

        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func completeImport(url: URL, location: MQTTCertificateLocation) {
        defer {
            url.stopAccessingSecurityScopedResource()
            pendingFileURL = nil
        }

        let certDir: URL?
        switch location {
        case .local:
            certDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Certificates")
        case .cloud:
            certDir = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents").appendingPathComponent("Certificates")
        }

        guard let dir = certDir else {
            errorMessage = location == .cloud ? "iCloud is not available" : "Cannot access documents"
            showError = true
            return
        }

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)

            file = MQTTCertificateFile(name: url.lastPathComponent, type: type, location: location)
        } catch {
            errorMessage = "Failed to copy file: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Certificate Help Sheet

struct MQTTCertificateHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(
                        title: "What is a PKCS#12 file?",
                        content: "A PKCS#12 file (.p12 or .pfx) is a secure container that bundles your client certificate and private key together, protected by a password."
                    )

                    helpSection(
                        title: "Creating a PKCS#12 file",
                        content: "If you have separate certificate (.crt) and key (.key) files, combine them using OpenSSL:"
                    )

                    codeBlock("""
                        openssl pkcs12 -export \\
                          -in client.crt \\
                          -inkey client.key \\
                          -out client.p12
                        """)

                    helpSection(
                        title: "Including a CA certificate",
                        content: "To include the CA certificate chain:"
                    )

                    codeBlock("""
                        openssl pkcs12 -export \\
                          -in client.crt \\
                          -inkey client.key \\
                          -certfile ca.crt \\
                          -out client.p12
                        """)

                    helpSection(
                        title: "Verifying your certificate",
                        content: "To verify the contents of a PKCS#12 file:"
                    )

                    codeBlock("openssl pkcs12 -info -in client.p12")

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Certificate Help")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private func codeBlock(_ code: String) -> some View {
        HStack {
            Text(code)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
            Spacer()
        }
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
