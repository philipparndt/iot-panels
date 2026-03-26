import Foundation
import CoreData

// MARK: - Export/Import Models (shared .mqttbroker schema)

/// JSON schema for `.mqttbroker` files.
/// This format is shared between MQTT apps for broker configuration exchange.
struct BrokerExportDocument: Codable {
    static let currentVersion = 1

    let version: Int
    let broker: BrokerExportModel

    init(broker: BrokerExportModel) {
        self.version = Self.currentVersion
        self.broker = broker
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> BrokerExportDocument {
        return try JSONDecoder().decode(BrokerExportDocument.self, from: data)
    }
}

struct BrokerExportModel: Codable {
    let alias: String
    let hostname: String
    let port: Int
    let protocolMethod: String
    let protocolVersion: String
    let basePath: String?
    let ssl: Bool
    let untrustedSSL: Bool
    let alpn: String?
    let authType: String
    let username: String?
    let password: String?
    let clientID: String?
    let subscriptions: [BrokerExportSubscription]
    let certificates: [BrokerExportCertificate]?
    let certClientKeyPassword: String?
    let category: String?
    let limitTopic: Int
    let limitMessagesBatch: Int
}

struct BrokerExportSubscription: Codable {
    let topic: String
    let qos: Int
}

struct BrokerExportCertificate: Codable {
    let name: String
    let type: String
    let data: String?
}

// MARK: - Export from DataSource

extension BrokerExportModel {
    /// Creates an export model from an IoT Panels DataSource.
    init(from ds: DataSource, includeSecrets: Bool = true) {
        self.alias = ds.wrappedName
        self.hostname = ds.wrappedHostname
        self.port = Int(ds.wrappedPort)
        self.protocolMethod = ds.wrappedProtocolMethod.rawValue
        self.protocolVersion = ds.wrappedProtocolVersion.rawValue
        self.basePath = ds.wrappedBasePath.isEmpty ? nil : ds.wrappedBasePath
        self.ssl = ds.wrappedSsl
        self.untrustedSSL = ds.wrappedUntrustedSSL
        self.alpn = ds.wrappedAlpn.isEmpty ? nil : ds.wrappedAlpn

        let hasUser = !(ds.wrappedUsername.isEmpty)
        let hasCert = ds.wrappedCertificates.contains { $0.type == .p12 || $0.type == .client }
        if hasUser && hasCert {
            self.authType = "both"
        } else if hasUser {
            self.authType = "usernamePassword"
        } else if hasCert {
            self.authType = "certificate"
        } else {
            self.authType = "none"
        }

        self.username = ds.wrappedUsername.isEmpty ? nil : ds.wrappedUsername
        self.password = includeSecrets && !ds.wrappedPassword.isEmpty ? ds.wrappedPassword : nil
        self.clientID = ds.wrappedClientID.isEmpty ? nil : ds.wrappedClientID
        self.subscriptions = ds.wrappedSubscriptions.map {
            BrokerExportSubscription(topic: $0.topic, qos: $0.qos)
        }

        if includeSecrets {
            let certs = ds.wrappedCertificates.map { cert -> BrokerExportCertificate in
                let base64: String? = cert.fileURL.flatMap { try? Data(contentsOf: $0).base64EncodedString() }
                return BrokerExportCertificate(name: cert.name, type: cert.type.rawValue, data: base64)
            }
            self.certificates = certs.isEmpty ? nil : certs
        } else {
            let certs = ds.wrappedCertificates.map { cert in
                BrokerExportCertificate(name: cert.name, type: cert.type.rawValue, data: nil)
            }
            self.certificates = certs.isEmpty ? nil : certs
        }

        self.certClientKeyPassword = includeSecrets ? (ds.wrappedCertClientKeyPassword.isEmpty ? nil : ds.wrappedCertClientKeyPassword) : nil
        self.category = nil
        self.limitTopic = 0
        self.limitMessagesBatch = 0
    }
}

// MARK: - Import to DataSource

extension BrokerExportModel {
    /// Applies the exported broker configuration to an IoT Panels DataSource.
    func apply(to target: DataSource) {
        target.name = alias.isEmpty ? hostname : alias
        target.backendType = BackendType.mqtt.rawValue
        target.hostname = hostname
        target.port = Int32(port)
        target.protocolMethod = protocolMethod
        target.protocolVersion = protocolVersion
        target.basePath = basePath
        target.ssl = ssl
        target.untrustedSSL = untrustedSSL
        target.alpn = alpn
        target.username = username
        target.password = password
        target.clientID = clientID
        target.certClientKeyPassword = certClientKeyPassword

        let subs = subscriptions.map { MQTTTopicSubscription(topic: $0.topic, qos: $0.qos) }
        target.wrappedSubscriptions = subs.isEmpty ? [MQTTTopicSubscription()] : subs

        if let exportedCerts = certificates {
            let imported = importCertificates(exportedCerts)
            target.wrappedCertificates = imported
        }
    }

    private func importCertificates(_ exported: [BrokerExportCertificate]) -> [MQTTCertificateFile] {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Certificates")

        if let dir = docsDir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        return exported.compactMap { cert in
            if let base64 = cert.data,
               let data = Data(base64Encoded: base64),
               let dir = docsDir {
                let fileURL = dir.appendingPathComponent(cert.name)
                try? data.write(to: fileURL)
            }

            let type: MQTTCertificateFileType
            switch cert.type {
            case "p12": type = .p12
            case "serverCA": type = .serverCA
            case "client": type = .client
            case "clientKey": type = .clientKey
            default: type = .undefined
            }

            return MQTTCertificateFile(name: cert.name, type: type, location: .local)
        }
    }
}

// MARK: - BrokerImportExport Service

class BrokerImportExport {

    /// Exports an MQTT DataSource to a temporary `.mqttbroker` file.
    static func exportBroker(_ dataSource: DataSource, includeSecrets: Bool = true) throws -> URL {
        let model = BrokerExportModel(from: dataSource, includeSecrets: includeSecrets)
        let document = BrokerExportDocument(broker: model)
        let data = try document.encode()

        let fileName = sanitizeFileName(dataSource.wrappedName) + ".mqttbroker"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        try data.write(to: fileURL)
        return fileURL
    }

    /// Imports a broker from a `.mqttbroker` file URL into an MQTT DataSource.
    @discardableResult
    static func importBroker(from url: URL, context: NSManagedObjectContext) throws -> DataSource {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let document = try BrokerExportDocument.decode(from: data)

        let ds = DataSource(context: context)
        ds.id = UUID()
        ds.createdAt = Date()
        ds.modifiedAt = Date()
        document.broker.apply(to: ds)

        try context.save()
        return ds
    }

    private static func sanitizeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let sanitized = name.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(sanitized)).trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? "broker" : result
    }
}
