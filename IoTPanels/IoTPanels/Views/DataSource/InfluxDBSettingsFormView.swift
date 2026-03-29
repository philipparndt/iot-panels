import SwiftUI

struct InfluxDBSettingsFormView: View {
    @Binding var url: String
    @Binding var authMethod: InfluxAuthMethod
    @Binding var token: String
    @Binding var username: String
    @Binding var password: String
    @Binding var organization: String
    @Binding var bucket: String

    // Discovery state
    @State private var discoveredOrgs: [InfluxOrganization] = []
    @State private var discoveredBuckets: [InfluxBucket] = []
    @State private var selectedOrgID: String?
    @State private var isDiscoveringOrgs = false
    @State private var isDiscoveringBuckets = false
    @State private var discoveryError: String?

    private var canDiscover: Bool {
        guard !url.isEmpty else { return false }
        switch authMethod {
        case .token:
            return !token.isEmpty
        case .usernamePassword:
            return !username.isEmpty && !password.isEmpty
        }
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
                Picker("Authentication", selection: $authMethod) {
                    ForEach(InfluxAuthMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
            }

            if authMethod == .token {
                Section("Token Authentication") {
                    SecureField("Token", text: $token)
                }
            } else {
                Section("Username & Password Authentication") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
            }

            Section {
                if isDiscoveringOrgs {
                    ProgressView("Loading organizations...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if !discoveredOrgs.isEmpty {
                    Picker("Organization", selection: $organization) {
                        Text("Select...").tag("")
                        ForEach(discoveredOrgs) { org in
                            Text(org.name).tag(org.name)
                        }
                    }
                    .onChange(of: organization) {
                        if let org = discoveredOrgs.first(where: { $0.name == organization }) {
                            selectedOrgID = org.id
                            discoverBuckets(orgID: org.id)
                        }
                    }
                } else {
                    TextField("Organization", text: $organization)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if isDiscoveringBuckets {
                    ProgressView("Loading buckets...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if !discoveredBuckets.isEmpty {
                    Picker("Bucket", selection: $bucket) {
                        Text("Select...").tag("")
                        ForEach(discoveredBuckets) { b in
                            Text(b.name).tag(b.name)
                        }
                    }
                } else {
                    TextField("Bucket", text: $bucket)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let discoveryError {
                    Label(discoveryError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            } header: {
                Text("InfluxDB 2")
            } footer: {
                if canDiscover && discoveredOrgs.isEmpty && !isDiscoveringOrgs {
                    Button("Discover Organizations & Buckets") {
                        discoverOrganizations()
                    }
                }
            }
        }
        .navigationTitle("InfluxDB Settings")
    }

    // MARK: - Discovery

    private func makeDiscoveryService() -> InfluxDB2Service {
        let resolved = normalizedUrl
        if authMethod == .usernamePassword {
            return InfluxDB2Service(url: resolved, username: username, password: password, organization: "", bucket: "")
        } else {
            return InfluxDB2Service(url: resolved, token: token, organization: "", bucket: "")
        }
    }

    private func discoverOrganizations() {
        isDiscoveringOrgs = true
        discoveryError = nil
        discoveredOrgs = []
        discoveredBuckets = []
        organization = ""
        bucket = ""
        selectedOrgID = nil

        let service = makeDiscoveryService()
        Task {
            do {
                let orgs = try await service.fetchOrganizations()
                await MainActor.run {
                    url = normalizedUrl
                    discoveredOrgs = orgs
                    isDiscoveringOrgs = false
                    if orgs.count == 1 {
                        organization = orgs[0].name
                        selectedOrgID = orgs[0].id
                        discoverBuckets(orgID: orgs[0].id)
                    }
                }
            } catch {
                await MainActor.run {
                    discoveryError = error.localizedDescription
                    isDiscoveringOrgs = false
                }
            }
        }
    }

    private func discoverBuckets(orgID: String) {
        isDiscoveringBuckets = true
        discoveryError = nil
        discoveredBuckets = []
        bucket = ""

        let service = makeDiscoveryService()
        Task {
            do {
                let buckets = try await service.fetchBuckets(orgID: orgID)
                await MainActor.run {
                    discoveredBuckets = buckets
                    isDiscoveringBuckets = false
                    if buckets.count == 1 {
                        bucket = buckets[0].name
                    }
                }
            } catch {
                await MainActor.run {
                    discoveryError = error.localizedDescription
                    isDiscoveringBuckets = false
                }
            }
        }
    }
}
