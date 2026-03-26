import Foundation
import Combine
import CocoaMQTT
import CocoaMQTTWebSocket

// MARK: - MQTTService

/// MQTT data source service implementing DataSourceServiceProtocol.
/// Uses a shared persistent connection manager so dashboard panels receive
/// values immediately instead of waiting for a fresh subscribe/collect cycle.
class MQTTService: DataSourceServiceProtocol {
    let hostname: String
    let port: UInt16
    let clientID: String
    let username: String?
    let password: String?
    let enableSSL: Bool
    let allowUntrustedSSL: Bool
    let protocolMethod: MQTTProtocolMethod
    let protocolVersion: MQTTProtocolVersion
    let basePath: String
    let subscriptions: [MQTTTopicSubscription]
    let certificates: [MQTTCertificateFile]
    let certPassword: String

    /// Stable key used by the connection manager to deduplicate connections.
    var connectionKey: String {
        "\(hostname):\(port):\(username ?? ""):\(enableSSL)"
    }

    init(dataSource: DataSource) {
        self.hostname = dataSource.wrappedHostname
        self.port = UInt16(dataSource.wrappedPort)
        self.clientID = dataSource.computedClientID
        self.username = dataSource.wrappedUsername.isEmpty ? nil : dataSource.wrappedUsername
        self.password = dataSource.wrappedPassword.isEmpty ? nil : dataSource.wrappedPassword
        self.enableSSL = dataSource.wrappedSsl
        self.allowUntrustedSSL = dataSource.wrappedUntrustedSSL
        self.protocolMethod = dataSource.wrappedProtocolMethod
        self.protocolVersion = dataSource.wrappedProtocolVersion
        self.basePath = dataSource.wrappedBasePath
        self.subscriptions = dataSource.wrappedSubscriptions
        self.certificates = dataSource.wrappedCertificates
        self.certPassword = dataSource.wrappedCertClientKeyPassword
    }

    /// Initializer for test connection from unsaved form fields.
    init(hostname: String, port: UInt16, clientID: String = "",
         username: String? = nil, password: String? = nil,
         enableSSL: Bool = false, allowUntrustedSSL: Bool = false,
         protocolMethod: MQTTProtocolMethod = .mqtt,
         protocolVersion: MQTTProtocolVersion = .mqtt3,
         basePath: String = "",
         subscriptions: [MQTTTopicSubscription] = [MQTTTopicSubscription()],
         certificates: [MQTTCertificateFile] = [],
         certPassword: String = "") {
        self.hostname = hostname
        self.port = port
        self.clientID = clientID.isEmpty ? "iotpanels-" + UUID().uuidString.prefix(8).lowercased() : clientID
        self.username = username
        self.password = password
        self.enableSSL = enableSSL
        self.allowUntrustedSSL = allowUntrustedSSL
        self.protocolMethod = protocolMethod
        self.protocolVersion = protocolVersion
        self.basePath = basePath
        self.subscriptions = subscriptions
        self.certificates = certificates
        self.certPassword = certPassword
    }

    // MARK: - DataSourceServiceProtocol

    func testConnection() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = MQTTConnectionHandler(service: self)
                handler.testConnection { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: true)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func fetchMeasurements() async throws -> [String] {
        subscriptions.map { $0.topic }
    }

    func fetchFieldKeys(measurement topic: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = MQTTConnectionHandler(service: self)
                handler.discoverFields(topic: topic, timeout: 5.0) { result in
                    switch result {
                    case .success(let fields):
                        continuation.resume(returning: fields)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func fetchTagKeys(measurement: String) async throws -> [String] {
        []
    }

    func fetchTagValues(measurement: String, tag: String) async throws -> [String] {
        []
    }

    func query(_ queryString: String) async throws -> QueryResult {
        let params = MQTTQueryParser.parse(queryString)
        let topic = params.topic
        let fields = params.fields
        let rangeSec = params.rangeSeconds

        let manager = MQTTConnectionManager.shared
        let messages = try await manager.getMessages(for: self, topic: topic, rangeSeconds: rangeSec)
        return MQTTConnectionHandler.buildQueryResult(from: messages, fields: fields)
    }
}

// MARK: - MQTTConnectionManager

/// Maintains persistent MQTT connections and caches messages per topic.
/// Dashboard panels get values immediately from the cache instead of
/// creating a new connection for every query.
final class MQTTConnectionManager {
    static let shared = MQTTConnectionManager()

    /// Fires the connection key + topic whenever a new message arrives.
    /// Views can filter by connection key and topic pattern to update on demand.
    let messageReceived = PassthroughSubject<(connectionKey: String, topic: String), Never>()

    private let lock = NSLock()
    private var connections: [String: ManagedConnection] = [:]

    private init() {}

    /// Returns cached messages for a topic, connecting if needed.
    /// If the connection is fresh and no messages are cached yet, waits briefly for the first message.
    func getMessages(for service: MQTTService, topic: String, rangeSeconds: TimeInterval) async throws -> [(topic: String, payload: String, timestamp: Date)] {
        let connection = getOrCreateConnection(for: service)

        // Ensure subscribed to this topic
        connection.ensureSubscribed(to: topic)

        // If we already have cached messages, return them immediately
        let cached = connection.messages(for: topic, within: rangeSeconds)
        if !cached.isEmpty {
            return cached
        }

        // If not connected, return empty immediately — don't block the caller.
        // autoReconnect will restore the connection; the Combine publisher
        // will push updates to the UI once messages arrive.
        guard connection.isConnected else {
            return []
        }

        // Connected but no cached messages yet — wait briefly for the first one
        return try await withCheckedThrowingContinuation { continuation in
            connection.waitForFirstMessage(topic: topic, timeout: 3.0) { messages in
                continuation.resume(returning: messages)
            }
        }
    }

    /// Disconnect and remove a specific connection (e.g. when data source is deleted).
    func disconnect(key: String) {
        lock.lock()
        let connection = connections.removeValue(forKey: key)
        lock.unlock()
        connection?.disconnect()
    }

    /// Disconnect all connections.
    func disconnectAll() {
        lock.lock()
        let all = connections
        connections.removeAll()
        lock.unlock()
        for (_, conn) in all {
            conn.disconnect()
        }
    }

    private func getOrCreateConnection(for service: MQTTService) -> ManagedConnection {
        lock.lock()
        defer { lock.unlock() }

        let key = service.connectionKey
        if let existing = connections[key], existing.isAlive {
            // Reuse existing connection — it has autoReconnect enabled
            // or a retry timer pending, so it will recover when the network returns.
            return existing
        }

        // Remove dead connection if any
        connections[key]?.disconnect()

        let connection = ManagedConnection(service: service) { [weak self] topic in
            self?.messageReceived.send((connectionKey: key, topic: topic))
        }
        connections[key] = connection
        connection.connect()
        return connection
    }
}

// MARK: - ManagedConnection

/// A single persistent MQTT connection that caches messages per topic.
private class ManagedConnection: NSObject {
    private let service: MQTTService
    private let onMessageReceived: (String) -> Void
    private var mqtt3: CocoaMQTT?
    private var mqtt5: CocoaMQTT5?
    private let lock = NSLock()
    private var subscribedTopics: Set<String> = []
    private var messageCache: [(topic: String, payload: String, timestamp: Date)] = []
    private var nextWaiterID: UInt64 = 0
    private var waiters: [(id: UInt64, topic: String, completion: ([(topic: String, payload: String, timestamp: Date)]) -> Void)] = []
    private(set) var isConnected = false
    private var isConnecting = false
    private var retryTimer: DispatchSourceTimer?

    /// Maximum number of cached messages per topic to prevent unbounded growth.
    private let maxCachePerTopic = 500
    /// Maximum age of cached messages.
    private let maxCacheAge: TimeInterval = 3600 // 1 hour

    /// Whether this connection is alive (connected, connecting, or has autoReconnect active).
    var isAlive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isConnected || isConnecting || mqtt3 != nil || mqtt5 != nil
    }

    init(service: MQTTService, onMessageReceived: @escaping (String) -> Void) {
        self.service = service
        self.onMessageReceived = onMessageReceived
        super.init()
    }

    func connect() {
        lock.lock()
        guard !isConnected, !isConnecting else {
            lock.unlock()
            return
        }
        isConnecting = true
        lock.unlock()

        cancelRetryTimer()

        if service.protocolVersion == .mqtt5 {
            connectMQTT5()
        } else {
            connectMQTT3()
        }
    }

    /// Schedules a retry if the initial connect() call failed (returned false).
    private func scheduleRetry() {
        cancelRetryTimer()
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + 5)
        timer.setEventHandler { [weak self] in
            self?.connect()
        }
        retryTimer = timer
        timer.resume()
    }

    private func cancelRetryTimer() {
        retryTimer?.cancel()
        retryTimer = nil
    }

    func disconnect() {
        cancelRetryTimer()

        lock.lock()
        isConnected = false
        isConnecting = false
        let pending = waiters
        waiters.removeAll()
        lock.unlock()

        // Resolve pending waiters with empty results
        for waiter in pending {
            waiter.completion([])
        }

        mqtt3?.disconnect()
        mqtt5?.disconnect()
        mqtt3 = nil
        mqtt5 = nil
    }

    func ensureSubscribed(to topic: String) {
        lock.lock()
        guard !subscribedTopics.contains(topic) else {
            lock.unlock()
            return
        }
        subscribedTopics.insert(topic)
        let connected = isConnected
        lock.unlock()

        if connected {
            subscribe(to: topic)
        }
    }

    func messages(for topic: String, within rangeSeconds: TimeInterval) -> [(topic: String, payload: String, timestamp: Date)] {
        let cutoff = Date().addingTimeInterval(-rangeSeconds)
        lock.lock()
        defer { lock.unlock() }
        return messageCache.filter { matchesTopic($0.topic, pattern: topic) && $0.timestamp >= cutoff }
    }

    func waitForFirstMessage(topic: String, timeout: TimeInterval, completion: @escaping ([(topic: String, payload: String, timestamp: Date)]) -> Void) {
        lock.lock()
        let waiterID = nextWaiterID
        nextWaiterID += 1
        waiters.append((id: waiterID, topic: topic, completion: completion))
        lock.unlock()

        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.resolveWaiter(id: waiterID)
        }
    }

    // MARK: - Private

    private func resolveWaiter(id: UInt64) {
        lock.lock()
        guard let idx = waiters.firstIndex(where: { $0.id == id }) else {
            // Already resolved by incoming message
            lock.unlock()
            return
        }
        let waiter = waiters.remove(at: idx)
        let cached = messageCache.filter { matchesTopic($0.topic, pattern: waiter.topic) }
        lock.unlock()

        waiter.completion(cached)
    }

    private func handleMessage(topic: String, payload: String) {
        let entry = (topic: topic, payload: payload, timestamp: Date())

        lock.lock()
        messageCache.append(entry)
        pruneCache()

        // Resolve waiters that match this topic
        let matching = waiters.filter { matchesTopic(topic, pattern: $0.topic) }
        let matchingIDs = Set(matching.map { $0.id })
        waiters.removeAll { matchingIDs.contains($0.id) }
        lock.unlock()

        for waiter in matching {
            let relevant = messages(for: waiter.topic, within: 3600)
            waiter.completion(relevant)
        }

        onMessageReceived(topic)
    }

    private func pruneCache() {
        // Remove old messages
        let cutoff = Date().addingTimeInterval(-maxCacheAge)
        messageCache.removeAll { $0.timestamp < cutoff }

        // Per-topic limit: keep only the latest N per topic
        var counts: [String: Int] = [:]
        // Iterate backwards so we keep the newest
        var toRemove: Set<Int> = []
        for i in stride(from: messageCache.count - 1, through: 0, by: -1) {
            let t = messageCache[i].topic
            counts[t, default: 0] += 1
            if counts[t]! > maxCachePerTopic {
                toRemove.insert(i)
            }
        }
        for i in toRemove.sorted(by: >) {
            messageCache.remove(at: i)
        }
    }

    /// Simple MQTT topic matching supporting + and # wildcards.
    private func matchesTopic(_ topic: String, pattern: String) -> Bool {
        if pattern == "#" { return true }
        let topicParts = topic.components(separatedBy: "/")
        let patternParts = pattern.components(separatedBy: "/")

        for (i, pp) in patternParts.enumerated() {
            if pp == "#" { return true }
            guard i < topicParts.count else { return false }
            if pp == "+" { continue }
            if pp != topicParts[i] { return false }
        }
        return topicParts.count == patternParts.count
    }

    // MARK: - MQTT3

    private func connectMQTT3() {
        let mqtt: CocoaMQTT
        if service.protocolMethod == .websocket {
            let path = service.basePath.isEmpty ? "/" : (service.basePath.hasPrefix("/") ? service.basePath : "/\(service.basePath)")
            let websocket = CocoaMQTTWebSocket(uri: path)
            mqtt = CocoaMQTT(clientID: service.clientID, host: service.hostname, port: service.port, socket: websocket)
        } else {
            mqtt = CocoaMQTT(clientID: service.clientID, host: service.hostname, port: service.port)
        }

        configureMQTT3(mqtt)
        self.mqtt3 = mqtt

        if !mqtt.connect() {
            lock.lock()
            isConnecting = false
            lock.unlock()
            self.mqtt3 = nil
            scheduleRetry()
        }
    }

    private func configureMQTT3(_ mqtt: CocoaMQTT) {
        mqtt.enableSSL = service.enableSSL
        mqtt.allowUntrustCACertificate = service.allowUntrustedSSL

        if let username = service.username { mqtt.username = username }
        if let password = service.password { mqtt.password = password }

        if let p12 = service.certificates.first(where: { $0.type == .p12 }),
           let url = p12.fileURL,
           let sslSettings = MQTTCertificateLoader.loadP12SSLSettings(url: url, password: service.certPassword) {
            mqtt.sslSettings = sslSettings
        }

        if service.enableSSL, !service.allowUntrustedSSL,
           let serverCA = service.certificates.first(where: { $0.type == .serverCA }),
           let url = serverCA.fileURL,
           let certs = try? MQTTCertificateLoader.loadServerCACerts(url: url) {
            mqtt.serverCACertificates = certs
        }

        mqtt.keepAlive = 30
        mqtt.autoReconnect = true
        mqtt.autoReconnectTimeInterval = 5

        mqtt.didConnectAck = { [weak self] _, ack in
            guard let self else { return }
            self.lock.lock()
            if ack == .accept {
                self.isConnected = true
                self.isConnecting = false
                let topics = self.subscribedTopics
                self.lock.unlock()
                // Re-subscribe to all topics after (re)connect
                for topic in topics {
                    self.subscribe(to: topic)
                }
            } else {
                self.isConnecting = false
                self.lock.unlock()
            }
        }

        mqtt.didReceiveMessage = { [weak self] _, message, _ in
            let payload = message.string ?? String(data: Data(message.payload), encoding: .utf8) ?? ""
            self?.handleMessage(topic: message.topic, payload: payload)
        }

        mqtt.didDisconnect = { [weak self] _, _ in
            self?.handleDisconnect()
        }
    }

    // MARK: - MQTT5

    private func connectMQTT5() {
        let mqtt: CocoaMQTT5
        if service.protocolMethod == .websocket {
            let path = service.basePath.isEmpty ? "/" : (service.basePath.hasPrefix("/") ? service.basePath : "/\(service.basePath)")
            let websocket = CocoaMQTTWebSocket(uri: path)
            mqtt = CocoaMQTT5(clientID: service.clientID, host: service.hostname, port: service.port, socket: websocket)
        } else {
            mqtt = CocoaMQTT5(clientID: service.clientID, host: service.hostname, port: service.port)
        }

        configureMQTT5(mqtt)
        self.mqtt5 = mqtt

        if !mqtt.connect() {
            lock.lock()
            isConnecting = false
            lock.unlock()
            self.mqtt5 = nil
            scheduleRetry()
        }
    }

    private func configureMQTT5(_ mqtt: CocoaMQTT5) {
        mqtt.enableSSL = service.enableSSL
        mqtt.allowUntrustCACertificate = service.allowUntrustedSSL

        if let username = service.username { mqtt.username = username }
        if let password = service.password { mqtt.password = password }

        if let p12 = service.certificates.first(where: { $0.type == .p12 }),
           let url = p12.fileURL,
           let sslSettings = MQTTCertificateLoader.loadP12SSLSettings(url: url, password: service.certPassword) {
            mqtt.sslSettings = sslSettings
        }

        if service.enableSSL, !service.allowUntrustedSSL,
           let serverCA = service.certificates.first(where: { $0.type == .serverCA }),
           let url = serverCA.fileURL,
           let certs = try? MQTTCertificateLoader.loadServerCACerts(url: url) {
            mqtt.serverCACertificates = certs
        }

        mqtt.keepAlive = 30
        mqtt.autoReconnect = true
        mqtt.autoReconnectTimeInterval = 5

        mqtt.didConnectAck = { [weak self] _, reasonCode, _ in
            guard let self else { return }
            self.lock.lock()
            if reasonCode == .success {
                self.isConnected = true
                self.isConnecting = false
                let topics = self.subscribedTopics
                self.lock.unlock()
                for topic in topics {
                    self.subscribe(to: topic)
                }
            } else {
                self.isConnecting = false
                self.lock.unlock()
            }
        }

        mqtt.didReceiveMessage = { [weak self] _, message, _, _ in
            let payload = message.string ?? String(data: Data(message.payload), encoding: .utf8) ?? ""
            self?.handleMessage(topic: message.topic, payload: payload)
        }

        mqtt.didDisconnect = { [weak self] _, _ in
            self?.handleDisconnect()
        }
    }

    // MARK: - Disconnect Handling

    private func handleDisconnect() {
        lock.lock()
        isConnected = false
        // Resolve all pending waiters immediately so callers don't hang
        let pending = waiters
        waiters.removeAll()
        lock.unlock()

        for waiter in pending {
            waiter.completion([])
        }
    }

    private func subscribe(to topic: String) {
        mqtt3?.subscribe(topic, qos: .qos0)
        mqtt5?.subscribe(topic, qos: .qos0)
    }
}

// MARK: - MQTTConnectionHandler

/// Handles ephemeral MQTT connection sessions for test and field discovery.
private class MQTTConnectionHandler: NSObject {
    private let service: MQTTService
    private var mqtt3: CocoaMQTT?
    private var mqtt5: CocoaMQTT5?
    private var onConnected: ((Result<Void, Error>) -> Void)?
    private var onMessage: ((String, String) -> Void)?
    private let lock = NSLock()

    init(service: MQTTService) {
        self.service = service
        super.init()
    }

    // MARK: - Test Connection

    func testConnection(completion: @escaping (Result<Void, Error>) -> Void) {
        connect { [weak self] result in
            switch result {
            case .success:
                self?.disconnect()
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Discover Fields

    func discoverFields(topic: String, timeout: TimeInterval, completion: @escaping (Result<[String], Error>) -> Void) {
        var discoveredFields: Set<String> = []
        let group = DispatchGroup()
        group.enter()
        var didLeave = false
        let leaveLock = NSLock()

        func leaveOnce() {
            leaveLock.lock()
            defer { leaveLock.unlock() }
            guard !didLeave else { return }
            didLeave = true
            group.leave()
        }

        onMessage = { _, payload in
            let fields = MQTTConnectionHandler.extractFieldNames(from: payload)
            leaveLock.lock()
            discoveredFields.formUnion(fields)
            leaveLock.unlock()
            leaveOnce()
        }

        connect { [weak self] result in
            switch result {
            case .success:
                self?.subscribe(to: topic)

                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    leaveOnce()
                }
            case .failure:
                leaveOnce()
            }
        }

        DispatchQueue.global().async {
            _ = group.wait(timeout: .now() + timeout + 1)
            let fields: [String]
            leaveLock.lock()
            fields = Array(discoveredFields).sorted()
            leaveLock.unlock()
            self.disconnect()
            completion(.success(fields.isEmpty ? ["value"] : fields))
        }
    }

    // MARK: - Build QueryResult

    static func buildQueryResult(from messages: [(topic: String, payload: String, timestamp: Date)], fields: [String]) -> QueryResult {
        let effectiveFields = fields.isEmpty ? ["value"] : fields
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var rows: [QueryResult.Row] = []

        for msg in messages {
            let values = extractFieldValues(from: msg.payload, fields: effectiveFields)
            for (field, value) in values {
                rows.append(QueryResult.Row(values: [
                    "_time": formatter.string(from: msg.timestamp),
                    "_field": field,
                    "_value": String(value),
                    "_measurement": msg.topic
                ]))
            }
        }

        let columns = [
            QueryResult.Column(name: "_time", type: "dateTime:RFC3339"),
            QueryResult.Column(name: "_field", type: "string"),
            QueryResult.Column(name: "_value", type: "double"),
            QueryResult.Column(name: "_measurement", type: "string")
        ]

        return QueryResult(columns: columns, rows: rows)
    }

    // MARK: - Connection

    private func connect(completion: @escaping (Result<Void, Error>) -> Void) {
        onConnected = completion

        if service.protocolVersion == .mqtt5 {
            connectMQTT5()
        } else {
            connectMQTT3()
        }
    }

    private func connectMQTT3() {
        let mqtt: CocoaMQTT
        if service.protocolMethod == .websocket {
            let path = service.basePath.isEmpty ? "/" : (service.basePath.hasPrefix("/") ? service.basePath : "/\(service.basePath)")
            let websocket = CocoaMQTTWebSocket(uri: path)
            mqtt = CocoaMQTT(clientID: service.clientID, host: service.hostname, port: service.port, socket: websocket)
        } else {
            mqtt = CocoaMQTT(clientID: service.clientID, host: service.hostname, port: service.port)
        }

        configureMQTT3(mqtt)
        self.mqtt3 = mqtt

        if !mqtt.connect() {
            onConnected?(.failure(MQTTError.connectionFailed("Could not initiate connection to \(service.hostname):\(service.port)")))
            onConnected = nil
        }
    }

    private func connectMQTT5() {
        let mqtt: CocoaMQTT5
        if service.protocolMethod == .websocket {
            let path = service.basePath.isEmpty ? "/" : (service.basePath.hasPrefix("/") ? service.basePath : "/\(service.basePath)")
            let websocket = CocoaMQTTWebSocket(uri: path)
            mqtt = CocoaMQTT5(clientID: service.clientID, host: service.hostname, port: service.port, socket: websocket)
        } else {
            mqtt = CocoaMQTT5(clientID: service.clientID, host: service.hostname, port: service.port)
        }

        configureMQTT5(mqtt)
        self.mqtt5 = mqtt

        if !mqtt.connect() {
            onConnected?(.failure(MQTTError.connectionFailed("Could not initiate connection to \(service.hostname):\(service.port)")))
            onConnected = nil
        }
    }

    private func configureMQTT3(_ mqtt: CocoaMQTT) {
        mqtt.enableSSL = service.enableSSL
        mqtt.allowUntrustCACertificate = service.allowUntrustedSSL

        if let username = service.username { mqtt.username = username }
        if let password = service.password { mqtt.password = password }

        if let p12 = service.certificates.first(where: { $0.type == .p12 }),
           let url = p12.fileURL,
           let sslSettings = MQTTCertificateLoader.loadP12SSLSettings(url: url, password: service.certPassword) {
            mqtt.sslSettings = sslSettings
        }

        if service.enableSSL, !service.allowUntrustedSSL,
           let serverCA = service.certificates.first(where: { $0.type == .serverCA }),
           let url = serverCA.fileURL,
           let certs = try? MQTTCertificateLoader.loadServerCACerts(url: url) {
            mqtt.serverCACertificates = certs
        }

        mqtt.keepAlive = 30
        mqtt.autoReconnect = false

        mqtt.didConnectAck = { [weak self] _, ack in
            if ack == .accept {
                self?.onConnected?(.success(()))
                self?.onConnected = nil
            } else {
                self?.onConnected?(.failure(MQTTError.connectionFailed(String(describing: ack))))
                self?.onConnected = nil
            }
        }

        mqtt.didReceiveMessage = { [weak self] _, message, _ in
            let payload = message.string ?? String(data: Data(message.payload), encoding: .utf8) ?? ""
            self?.onMessage?(message.topic, payload)
        }

        mqtt.didDisconnect = { [weak self] _, error in
            if let onConnected = self?.onConnected {
                let reason = error?.localizedDescription ?? "Disconnected"
                onConnected(.failure(MQTTError.connectionFailed(reason)))
                self?.onConnected = nil
            }
        }
    }

    private func configureMQTT5(_ mqtt: CocoaMQTT5) {
        mqtt.enableSSL = service.enableSSL
        mqtt.allowUntrustCACertificate = service.allowUntrustedSSL

        if let username = service.username { mqtt.username = username }
        if let password = service.password { mqtt.password = password }

        if let p12 = service.certificates.first(where: { $0.type == .p12 }),
           let url = p12.fileURL,
           let sslSettings = MQTTCertificateLoader.loadP12SSLSettings(url: url, password: service.certPassword) {
            mqtt.sslSettings = sslSettings
        }

        if service.enableSSL, !service.allowUntrustedSSL,
           let serverCA = service.certificates.first(where: { $0.type == .serverCA }),
           let url = serverCA.fileURL,
           let certs = try? MQTTCertificateLoader.loadServerCACerts(url: url) {
            mqtt.serverCACertificates = certs
        }

        mqtt.keepAlive = 30
        mqtt.autoReconnect = false

        mqtt.didConnectAck = { [weak self] _, reasonCode, _ in
            if reasonCode == .success {
                self?.onConnected?(.success(()))
                self?.onConnected = nil
            } else {
                self?.onConnected?(.failure(MQTTError.connectionFailed(String(describing: reasonCode))))
                self?.onConnected = nil
            }
        }

        mqtt.didReceiveMessage = { [weak self] _, message, _, _ in
            let payload = message.string ?? String(data: Data(message.payload), encoding: .utf8) ?? ""
            self?.onMessage?(message.topic, payload)
        }

        mqtt.didDisconnect = { [weak self] _, error in
            if let onConnected = self?.onConnected {
                let reason = error?.localizedDescription ?? "Disconnected"
                onConnected(.failure(MQTTError.connectionFailed(reason)))
                self?.onConnected = nil
            }
        }
    }

    private func subscribe(to topic: String) {
        mqtt3?.subscribe(topic, qos: .qos0)
        mqtt5?.subscribe(topic, qos: .qos0)
    }

    private func disconnect() {
        mqtt3?.disconnect()
        mqtt5?.disconnect()
        mqtt3 = nil
        mqtt5 = nil
    }

    // MARK: - Payload Parsing

    static func extractFieldNames(from payload: String) -> [String] {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return Double(payload) != nil ? ["value"] : []
        }
        return json.keys.filter { key in
            if let num = json[key] as? NSNumber {
                return CFBooleanGetTypeID() != CFGetTypeID(num)
            }
            if let str = json[key] as? String {
                return Double(str) != nil
            }
            return false
        }.sorted()
    }

    static func extractFieldValues(from payload: String, fields: [String]) -> [String: Double] {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let value = Double(payload) {
                return ["value": value]
            }
            return [:]
        }

        var result: [String: Double] = [:]
        for field in fields {
            if let num = json[field] as? NSNumber {
                if CFBooleanGetTypeID() != CFGetTypeID(num) {
                    result[field] = num.doubleValue
                }
            } else if let str = json[field] as? String, let val = Double(str) {
                result[field] = val
            }
        }
        return result
    }
}

// MARK: - MQTTCertificateLoader

/// Shared certificate loading used by both ManagedConnection and MQTTConnectionHandler.
enum MQTTCertificateLoader {
    static func loadP12SSLSettings(url: URL, password: String) -> [String: NSObject]? {
        guard let p12Data = NSData(contentsOf: url) else { return nil }
        let options = [kSecImportExportPassphrase as String: password] as NSDictionary
        var items: CFArray?
        let status = SecPKCS12Import(p12Data, options, &items)
        guard status == errSecSuccess,
              let array = items as? [[String: Any]],
              let identity = array.first?[kSecImportItemIdentity as String] else {
            return nil
        }
        return [kCFStreamSSLCertificates as String: [identity] as CFArray]
    }

    static func loadServerCACerts(url: URL) throws -> [SecCertificate] {
        guard let data = try? Data(contentsOf: url) else { return [] }

        if let cert = SecCertificateCreateWithData(nil, data as CFData) {
            return [cert]
        }

        guard let pemString = String(data: data, encoding: .utf8) else { return [] }
        let pattern = "-----BEGIN CERTIFICATE-----([\\s\\S]*?)-----END CERTIFICATE-----"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: pemString, range: NSRange(pemString.startIndex..., in: pemString))

        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: pemString) else { return nil }
            let base64 = pemString[range]
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard let certData = Data(base64Encoded: base64) else { return nil }
            return SecCertificateCreateWithData(nil, certData as CFData)
        }
    }
}

// MARK: - MQTTQueryParser

struct MQTTQueryParser {
    struct Params {
        var topic: String = "#"
        var fields: [String] = []
        var rangeSeconds: TimeInterval = 10
    }

    static func parse(_ queryString: String) -> Params {
        var params = Params()
        let parts = queryString.components(separatedBy: "|")
        for part in parts {
            let kv = part.components(separatedBy: ":")
            guard kv.count >= 2 else { continue }
            let key = kv[0].trimmingCharacters(in: .whitespaces)
            let value = kv.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            switch key {
            case "topic":
                params.topic = value
            case "fields":
                params.fields = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "range":
                params.rangeSeconds = TimeInterval(value) ?? 10
            default:
                break
            }
        }
        return params
    }

    static func build(topic: String, fields: [String], rangeSeconds: TimeInterval) -> String {
        let fieldsStr = fields.joined(separator: ",")
        return "topic:\(topic)|fields:\(fieldsStr)|range:\(Int(rangeSeconds))"
    }
}

// MARK: - MQTT Errors

enum MQTTError: LocalizedError {
    case connectionFailed(String)
    case timeout
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason): return "MQTT connection failed: \(reason)"
        case .timeout: return "MQTT connection timed out"
        case .invalidConfiguration(let reason): return "Invalid MQTT configuration: \(reason)"
        }
    }
}
