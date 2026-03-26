import Foundation

// MARK: - Protocol Enums

enum MQTTProtocolMethod: String, CaseIterable, Identifiable {
    case mqtt
    case websocket

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mqtt: return "MQTT"
        case .websocket: return "WebSocket"
        }
    }
}

enum MQTTProtocolVersion: String, CaseIterable, Identifiable {
    case mqtt3
    case mqtt5

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mqtt3: return "3.1.1"
        case .mqtt5: return "5.0"
        }
    }
}

// MARK: - Topic Subscription

struct MQTTTopicSubscription: Codable, Identifiable, Equatable {
    var id = UUID()
    var topic: String
    var qos: Int

    init(topic: String = "#", qos: Int = 0) {
        self.topic = topic
        self.qos = qos
    }
}

// MARK: - Certificate Models

enum MQTTCertificateFileType: String, Codable {
    case p12
    case serverCA
    case client
    case clientKey
    case undefined
}

enum MQTTCertificateLocation: String, Codable {
    case local
    case cloud
}

struct MQTTCertificateFile: Codable, Equatable {
    let name: String
    var type: MQTTCertificateFileType
    var location: MQTTCertificateLocation

    var fileURL: URL? {
        switch location {
        case .local:
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            return docs?.appendingPathComponent("Certificates").appendingPathComponent(name)
        case .cloud:
            guard let icloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents").appendingPathComponent("Certificates") else {
                return nil
            }
            return icloudURL.appendingPathComponent(name)
        }
    }
}

// MARK: - Authentication Type

enum MQTTAuthType: String, Codable {
    case none
    case usernamePassword
    case certificate
    case both
}

// MARK: - JSON Helpers

extension Array where Element == MQTTTopicSubscription {
    func toJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func fromJSON(_ json: String?) -> [MQTTTopicSubscription] {
        guard let json, let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode([MQTTTopicSubscription].self, from: data) else {
            return [MQTTTopicSubscription()]
        }
        return result
    }
}

extension Array where Element == MQTTCertificateFile {
    func toJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func fromJSON(_ json: String?) -> [MQTTCertificateFile] {
        guard let json, let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode([MQTTCertificateFile].self, from: data) else {
            return []
        }
        return result
    }
}
