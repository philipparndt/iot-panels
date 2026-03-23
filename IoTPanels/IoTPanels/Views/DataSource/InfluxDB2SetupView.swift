import SwiftUI

struct InfluxDB2SetupResult {
    let url: String
    let token: String
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
            case .connect: return "Sign In"
            case .organization: return "Organization"
            case .bucket: return "Bucket"
            case .finish: return "Done"
            }
        }
    }

    @State private var step: Step = .connect

    // Connection
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    // Session
    @State private var sessionService: InfluxDB2SessionService?

    // Organization
    @State private var organizations: [InfluxOrganization] = []
    @State private var selectedOrg: InfluxOrganization?

    // Bucket
    @State private var buckets: [InfluxBucket] = []
    @State private var selectedBucket: InfluxBucket?

    // Result
    @State private var createdToken: String?
    @State private var isCreatingToken = false

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Task { await sessionService?.signOut() }
                        dismiss()
                    }
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
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Username", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Password", text: $password)
                .textContentType(.password)
        } header: {
            Text("Connection")
        } footer: {
            Text("Your password is only used to sign in and create an API token. It will not be stored.")
        }

        Section {
            Button(action: signIn) {
                HStack {
                    Text("Sign In")
                    Spacer()
                    if isSigningIn {
                        ProgressView()
                    }
                }
            }
            .disabled(url.isEmpty || username.isEmpty || password.isEmpty || isSigningIn)
        }
    }

    @ViewBuilder
    private var organizationStep: some View {
        Section("Select Organization") {
            if organizations.isEmpty {
                ProgressView("Loading organizations...")
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
            } else {
                ForEach(Array(buckets.enumerated()), id: \.element.id) { _, bucket in
                    Button {
                        selectedBucket = bucket
                        createToken()
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
                HStack {
                    ProgressView()
                    Text("Creating API token...")
                        .padding(.leading, 8)
                }
            }
        } else if let token = createdToken, let org = selectedOrg, let bucket = selectedBucket {
            Section("Configuration Summary") {
                LabeledContent("Server", value: url)
                LabeledContent("Organization", value: org.name)
                LabeledContent("Bucket", value: bucket.name)
                LabeledContent("Token") {
                    Text(String(token.prefix(12)) + "...")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Use This Configuration") {
                    Task { await sessionService?.signOut() }
                    onComplete(InfluxDB2SetupResult(
                        url: url,
                        token: token,
                        organization: org.name,
                        bucket: bucket.name
                    ))
                }
                .font(.headline)
            }
        }
    }

    // MARK: - Actions

    private func signIn() {
        isSigningIn = true
        errorMessage = nil

        let normalizedUrl = url.hasSuffix("/") ? String(url.dropLast()) : url
        let service = InfluxDB2SessionService(url: normalizedUrl)
        self.url = normalizedUrl

        Task {
            do {
                try await service.signIn(username: username, password: password)
                let orgs = try await service.fetchOrganizations()
                await MainActor.run {
                    sessionService = service
                    organizations = orgs
                    isSigningIn = false
                    if orgs.count == 1 {
                        selectedOrg = orgs[0]
                        step = .organization
                        loadBuckets(orgID: orgs[0].id)
                    } else {
                        step = .organization
                    }
                }
            } catch {
                print("InfluxDB sign-in error: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSigningIn = false
                }
            }
        }
    }

    private func loadBuckets(orgID: String) {
        errorMessage = nil
        step = .bucket
        buckets = []

        Task {
            do {
                let result = try await sessionService?.fetchBuckets(orgID: orgID) ?? []
                await MainActor.run {
                    buckets = result
                    if result.count == 1 {
                        selectedBucket = result[0]
                        createToken()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func createToken() {
        guard let org = selectedOrg, let bucket = selectedBucket else { return }
        errorMessage = nil
        isCreatingToken = true
        step = .finish

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
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreatingToken = false
                }
            }
        }
    }
}
