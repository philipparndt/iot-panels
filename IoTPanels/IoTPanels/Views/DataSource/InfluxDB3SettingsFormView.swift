import SwiftUI

struct InfluxDB3SettingsFormView: View {
    @Binding var url: String
    @Binding var token: String
    @Binding var database: String

    @State private var isDiscovering = false
    @State private var discoveredDatabases: [String] = []
    @State private var discoveryError: String?

    private var canDiscover: Bool {
        !url.isEmpty
    }

    private var normalizedUrl: String {
        let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
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
                SecureField("Token (optional)", text: $token)
            } header: {
                Text("Authentication")
            } footer: {
                Text("Leave empty for unauthenticated access.")
            }

            Section {
                if isDiscovering {
                    ProgressView("Loading databases...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if !discoveredDatabases.isEmpty {
                    Picker("Database", selection: $database) {
                        Text("Select...").tag("")
                        ForEach(discoveredDatabases, id: \.self) { db in
                            Text(db).tag(db)
                        }
                    }
                } else {
                    TextField("Database", text: $database)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let discoveryError {
                    Label(discoveryError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            } header: {
                Text("InfluxDB 3")
            } footer: {
                if canDiscover && discoveredDatabases.isEmpty && !isDiscovering {
                    Button("Discover Databases") {
                        discoverDatabases()
                    }
                }
            }
        }
        .navigationTitle("InfluxDB 3 Settings")
    }

    // MARK: - Discovery

    private func discoverDatabases() {
        isDiscovering = true
        discoveryError = nil
        discoveredDatabases = []
        database = ""

        let service = InfluxDB3Service(url: normalizedUrl, token: token, database: "")
        Task {
            do {
                let databases = try await service.fetchDatabases()
                await MainActor.run {
                    url = normalizedUrl
                    discoveredDatabases = databases
                    isDiscovering = false
                    if databases.count == 1 {
                        self.database = databases[0]
                    }
                }
            } catch {
                await MainActor.run {
                    discoveryError = error.localizedDescription
                    isDiscovering = false
                }
            }
        }
    }
}
