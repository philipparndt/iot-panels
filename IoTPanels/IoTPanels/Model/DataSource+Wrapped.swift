import Foundation

extension DataSource {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedName: String {
        get { name ?? "" }
        set { name = newValue }
    }

    var wrappedBackendType: BackendType {
        get { BackendType(rawValue: backendType ?? "") ?? .influxDB2 }
        set { backendType = newValue.rawValue }
    }

    var wrappedUrl: String {
        get { url ?? "" }
        set { url = newValue }
    }

    var wrappedToken: String {
        get { token ?? "" }
        set { token = newValue }
    }

    var wrappedOrganization: String {
        get { organization ?? "" }
        set { organization = newValue }
    }

    var wrappedBucket: String {
        get { bucket ?? "" }
        set { bucket = newValue }
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }

    // MARK: - MQTT Properties

    var wrappedHostname: String {
        get { hostname ?? "" }
        set { hostname = newValue }
    }

    var wrappedPort: Int32 {
        get { port }
        set { port = newValue }
    }

    var wrappedClientID: String {
        get { clientID ?? "" }
        set { clientID = newValue }
    }

    var wrappedUsername: String {
        get { username ?? "" }
        set { username = newValue }
    }

    var wrappedPassword: String {
        get { password ?? "" }
        set { password = newValue }
    }

    var wrappedSsl: Bool {
        get { ssl }
        set { ssl = newValue }
    }

    var wrappedUntrustedSSL: Bool {
        get { untrustedSSL }
        set { untrustedSSL = newValue }
    }

    var wrappedProtocolMethod: MQTTProtocolMethod {
        get { MQTTProtocolMethod(rawValue: protocolMethod ?? "") ?? .mqtt }
        set { protocolMethod = newValue.rawValue }
    }

    var wrappedProtocolVersion: MQTTProtocolVersion {
        get { MQTTProtocolVersion(rawValue: protocolVersion ?? "") ?? .mqtt3 }
        set { protocolVersion = newValue.rawValue }
    }

    var wrappedBasePath: String {
        get { basePath ?? "" }
        set { basePath = newValue }
    }

    var wrappedSubscriptions: [MQTTTopicSubscription] {
        get { [MQTTTopicSubscription].fromJSON(subscriptionsJSON) }
        set { subscriptionsJSON = newValue.toJSON() }
    }

    var wrappedCertificates: [MQTTCertificateFile] {
        get { [MQTTCertificateFile].fromJSON(certificatesJSON) }
        set { certificatesJSON = newValue.toJSON() }
    }

    var wrappedCertClientKeyPassword: String {
        get { certClientKeyPassword ?? "" }
        set { certClientKeyPassword = newValue }
    }

    var wrappedAlpn: String {
        get { alpn ?? "" }
        set { alpn = newValue }
    }

    /// Returns the computed client ID, auto-generating one if the user left it empty.
    var computedClientID: String {
        let id = wrappedClientID
        if id.trimmingCharacters(in: .whitespaces).isEmpty {
            return "iotpanels-" + UUID().uuidString.prefix(8).lowercased()
        }
        return id
    }

    func mqttCertificate(ofType type: MQTTCertificateFileType) -> MQTTCertificateFile? {
        wrappedCertificates.first { $0.type == type }
    }
}
