import Foundation
import SQLite3

/// Persistent time-series store for MQTT data points, backed by local SQLite.
/// Thread-safe via a serial DispatchQueue. Buffers writes for performance.
final class MQTTDataStore {
    static let shared = MQTTDataStore()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "MQTTDataStore", qos: .utility)

    // Write buffer
    private var buffer: [(storeKey: String, timestamp: Date, field: String, value: Double)] = []
    private var lastFlush = Date.distantPast
    private let flushInterval: TimeInterval = 1.0
    private let flushThreshold = 100

    // Retention
    private let retentionSeconds: TimeInterval = 86400 // 24 hours
    private var lastPrune = Date.distantPast
    private let pruneInterval: TimeInterval = 60 // once per minute

    // Subscription registry: maps topic patterns to (connectionKey, fields, storeKey)
    private var subscriptions: [String: [(connectionKey: String, fields: [String], storeKey: String)]] = [:]

    private init() {
        queue.sync { self.openDatabase() }
    }

    /// Creates an isolated instance backed by an in-memory SQLite database (for tests).
    static func makeTestInstance() -> MQTTDataStore {
        let instance = MQTTDataStore(inMemory: true)
        return instance
    }

    private init(inMemory: Bool) {
        queue.sync { self.openDatabase(path: ":memory:") }
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let dbURL = appSupport.appendingPathComponent("mqtt_data.sqlite")
        openDatabase(path: dbURL.path)
    }

    private func openDatabase(path: String) {

        guard sqlite3_open(path, &db) == SQLITE_OK else {
            print("MQTTDataStore: Failed to open database")
            return
        }

        // Enable WAL mode for better concurrent read/write performance
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)

        let createTable = """
        CREATE TABLE IF NOT EXISTS data_points (
            store_key TEXT NOT NULL,
            timestamp REAL NOT NULL,
            field TEXT NOT NULL,
            value REAL NOT NULL,
            PRIMARY KEY (store_key, timestamp, field)
        )
        """
        sqlite3_exec(db, createTable, nil, nil, nil)

        let createIndex = "CREATE INDEX IF NOT EXISTS idx_key_time ON data_points (store_key, timestamp)"
        sqlite3_exec(db, createIndex, nil, nil, nil)
    }

    // MARK: - Store Key

    static func storeKey(connectionKey: String, topic: String, fields: [String]) -> String {
        let sortedFields = fields.sorted().joined(separator: ",")
        return "\(connectionKey)|\(topic)|\(sortedFields)"
    }

    // MARK: - Subscription Registry

    func register(connectionKey: String, topic: String, fields: [String]) {
        let key = MQTTDataStore.storeKey(connectionKey: connectionKey, topic: topic, fields: fields)
        queue.async {
            var subs = self.subscriptions[topic] ?? []
            if !subs.contains(where: { $0.storeKey == key }) {
                subs.append((connectionKey: connectionKey, fields: fields, storeKey: key))
                self.subscriptions[topic] = subs
            }
        }
    }

    func unregister(connectionKey: String, topic: String, fields: [String]) {
        let key = MQTTDataStore.storeKey(connectionKey: connectionKey, topic: topic, fields: fields)
        queue.async {
            self.subscriptions[topic]?.removeAll { $0.storeKey == key }
            if self.subscriptions[topic]?.isEmpty == true {
                self.subscriptions.removeValue(forKey: topic)
            }
        }
    }

    /// Called by ManagedConnection when a message arrives. Parses the payload
    /// for all registered subscriptions matching the topic and appends data points.
    /// `extractFields` is a closure that parses the payload for the given fields — this
    /// avoids a compile-time dependency on MQTTConnectionHandler.
    func handleMessage(connectionKey: String, topic: String, payload: String, timestamp: Date,
                       extractFields: @escaping (String, [String]) -> [String: Double]) {
        queue.async {
            // Find all subscriptions whose topic pattern matches this message's topic
            for (pattern, subs) in self.subscriptions {
                guard self.matchesTopic(topic, pattern: pattern) else { continue }
                for sub in subs where sub.connectionKey == connectionKey {
                    let values = extractFields(payload, sub.fields)
                    for (field, value) in values {
                        self.buffer.append((storeKey: sub.storeKey, timestamp: timestamp, field: field, value: value))
                    }
                }
            }

            self.flushIfNeeded()
            self.pruneIfNeeded()
        }
    }

    // MARK: - Append

    func append(points: [(storeKey: String, timestamp: Date, field: String, value: Double)]) {
        guard !points.isEmpty else { return }
        queue.async {
            self.buffer.append(contentsOf: points)
            self.flushIfNeeded()
            self.pruneIfNeeded()
        }
    }

    // MARK: - Query

    func query(forKey storeKey: String, since duration: TimeInterval) -> [ChartDataPoint] {
        queue.sync {
            flushBuffer() // ensure all buffered data is persisted before querying

            guard let db = self.db else { return [] }

            let cutoff = Date().addingTimeInterval(-duration).timeIntervalSince1970
            let sql = "SELECT timestamp, field, value FROM data_points WHERE store_key = ? AND timestamp >= ? ORDER BY timestamp ASC"

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (storeKey as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, cutoff)

            var results: [ChartDataPoint] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_double(stmt, 0)
                let field = String(cString: sqlite3_column_text(stmt, 1))
                let value = sqlite3_column_double(stmt, 2)
                results.append(ChartDataPoint(
                    time: Date(timeIntervalSince1970: timestamp),
                    value: value,
                    field: field
                ))
            }

            return results
        }
    }

    // MARK: - Write Buffer

    private func flushIfNeeded() {
        let now = Date()
        if buffer.count >= flushThreshold || now.timeIntervalSince(lastFlush) >= flushInterval {
            flushBuffer()
        }
    }

    private func flushBuffer() {
        guard !buffer.isEmpty, let db = self.db else { return }

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        let sql = "INSERT OR IGNORE INTO data_points (store_key, timestamp, field, value) VALUES (?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return
        }

        for point in buffer {
            sqlite3_reset(stmt)
            sqlite3_bind_text(stmt, 1, (point.storeKey as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, point.timestamp.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 3, (point.field as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 4, point.value)
            sqlite3_step(stmt)
        }

        sqlite3_finalize(stmt)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)

        buffer.removeAll(keepingCapacity: true)
        lastFlush = Date()
    }

    // MARK: - Retention

    private func pruneIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastPrune) >= pruneInterval else { return }
        lastPrune = now

        guard let db = self.db else { return }
        let cutoff = now.addingTimeInterval(-retentionSeconds).timeIntervalSince1970
        let sql = "DELETE FROM data_points WHERE timestamp < ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_double(stmt, 1, cutoff)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    // MARK: - Topic Matching

    private func matchesTopic(_ topic: String, pattern: String) -> Bool {
        if pattern == "#" { return true }
        let topicParts = topic.split(separator: "/", omittingEmptySubsequences: false)
        let patternParts = pattern.split(separator: "/", omittingEmptySubsequences: false)

        var ti = 0, pi = 0
        while pi < patternParts.count {
            let pp = patternParts[pi]
            if pp == "#" { return true }
            guard ti < topicParts.count else { return false }
            if pp != "+" && pp != topicParts[ti] { return false }
            ti += 1
            pi += 1
        }
        return ti == topicParts.count
    }
}
