import XCTest
@testable import IoTPanels

final class MQTTDataStoreTests: XCTestCase {

    private var store: MQTTDataStore!
    private let testKey = "test|sensors/temp|temperature"

    override func setUp() {
        super.setUp()
        store = MQTTDataStore.makeTestInstance()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Store Key

    func testStoreKeyDerived() {
        let key = MQTTDataStore.storeKey(connectionKey: "host:1883:user:true", topic: "sensors/temp", fields: ["humidity", "temperature"])
        XCTAssertEqual(key, "host:1883:user:true|sensors/temp|humidity,temperature")
    }

    func testStoreKeyFieldsSorted() {
        let key1 = MQTTDataStore.storeKey(connectionKey: "c", topic: "t", fields: ["b", "a"])
        let key2 = MQTTDataStore.storeKey(connectionKey: "c", topic: "t", fields: ["a", "b"])
        XCTAssertEqual(key1, key2)
    }

    // MARK: - Append & Query

    func testAppendAndQuery() {
        let now = Date()
        store.append(points: [
            (storeKey: testKey, timestamp: now.addingTimeInterval(-60), field: "temperature", value: 21.5),
            (storeKey: testKey, timestamp: now.addingTimeInterval(-30), field: "temperature", value: 22.0),
            (storeKey: testKey, timestamp: now, field: "temperature", value: 22.5),
        ])

        let results = store.query(forKey: testKey, since: 120)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].value, 21.5)
        XCTAssertEqual(results[1].value, 22.0)
        XCTAssertEqual(results[2].value, 22.5)
    }

    func testQueryFiltersByTimeRange() {
        let now = Date()
        store.append(points: [
            (storeKey: testKey, timestamp: now.addingTimeInterval(-3600), field: "temperature", value: 20.0),
            (storeKey: testKey, timestamp: now.addingTimeInterval(-60), field: "temperature", value: 22.0),
            (storeKey: testKey, timestamp: now, field: "temperature", value: 23.0),
        ])

        // Query last 120 seconds — should exclude the 1-hour-old point
        let results = store.query(forKey: testKey, since: 120)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].value, 22.0)
        XCTAssertEqual(results[1].value, 23.0)
    }

    func testQueryReturnsEmptyForUnknownKey() {
        store.append(points: [
            (storeKey: testKey, timestamp: Date(), field: "temperature", value: 22.0),
        ])
        let results = store.query(forKey: "unknown|key|fields", since: 3600)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Deduplication

    func testDuplicatePointsIgnored() {
        let now = Date()
        let point = (storeKey: testKey, timestamp: now, field: "temperature", value: 22.0)

        store.append(points: [point])
        store.append(points: [point])

        let results = store.query(forKey: testKey, since: 60)
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Data Isolation

    func testDifferentKeysAreIsolated() {
        let now = Date()
        let keyA = MQTTDataStore.storeKey(connectionKey: "c", topic: "t", fields: ["temperature"])
        let keyB = MQTTDataStore.storeKey(connectionKey: "c", topic: "t", fields: ["humidity"])

        store.append(points: [
            (storeKey: keyA, timestamp: now, field: "temperature", value: 22.0),
            (storeKey: keyB, timestamp: now, field: "humidity", value: 65.0),
        ])

        let resultsA = store.query(forKey: keyA, since: 60)
        let resultsB = store.query(forKey: keyB, since: 60)
        XCTAssertEqual(resultsA.count, 1)
        XCTAssertEqual(resultsA[0].field, "temperature")
        XCTAssertEqual(resultsB.count, 1)
        XCTAssertEqual(resultsB[0].field, "humidity")
    }

    // MARK: - Time Range Change Preserves Data

    func testChangingTimeRangeDoesNotDiscardData() {
        let now = Date()
        store.append(points: [
            (storeKey: testKey, timestamp: now.addingTimeInterval(-7000), field: "temperature", value: 20.0),
            (storeKey: testKey, timestamp: now.addingTimeInterval(-1500), field: "temperature", value: 21.0),
            (storeKey: testKey, timestamp: now.addingTimeInterval(-60), field: "temperature", value: 22.0),
        ])

        // Query with 3h range — all 3 points
        let results3h = store.query(forKey: testKey, since: 10800)
        XCTAssertEqual(results3h.count, 3)

        // Query with 30m range — only 2 recent points
        let results30m = store.query(forKey: testKey, since: 1800)
        XCTAssertEqual(results30m.count, 2)

        // Query with 3h again — still 3 points (data was not discarded)
        let results3hAgain = store.query(forKey: testKey, since: 10800)
        XCTAssertEqual(results3hAgain.count, 3)
    }

    // MARK: - Subscription Registry & handleMessage

    func testHandleMessageParsesAndStores() {
        let connKey = "host:1883::false"
        let topic = "sensors/temp"
        let fields = ["temperature"]
        let key = MQTTDataStore.storeKey(connectionKey: connKey, topic: topic, fields: fields)

        store.register(connectionKey: connKey, topic: topic, fields: fields)

        // Simulate a message arriving — use a synchronous extract function
        let expectation = expectation(description: "message stored")
        store.handleMessage(
            connectionKey: connKey,
            topic: topic,
            payload: "{\"temperature\": 22.5}",
            timestamp: Date(),
            extractFields: { payload, fields in
                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
                var result: [String: Double] = [:]
                for f in fields {
                    if let v = json[f] as? Double { result[f] = v }
                }
                return result
            }
        )

        // handleMessage is async on the queue, so give it a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let results = self.store.query(forKey: key, since: 60)
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results[0].value, 22.5)
            XCTAssertEqual(results[0].field, "temperature")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testUnregisteredTopicNotStored() {
        let connKey = "host:1883::false"
        store.handleMessage(
            connectionKey: connKey,
            topic: "sensors/temp",
            payload: "{\"temperature\": 22.5}",
            timestamp: Date(),
            extractFields: { _, _ in ["temperature": 22.5] }
        )

        let expectation = expectation(description: "not stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let key = MQTTDataStore.storeKey(connectionKey: connKey, topic: "sensors/temp", fields: ["temperature"])
            let results = self.store.query(forKey: key, since: 60)
            XCTAssertTrue(results.isEmpty)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Topic Matching

    func testWildcardTopicMatching() {
        let connKey = "c"
        let fields = ["value"]

        store.register(connectionKey: connKey, topic: "sensors/+/temp", fields: fields)
        let key = MQTTDataStore.storeKey(connectionKey: connKey, topic: "sensors/+/temp", fields: fields)

        store.handleMessage(
            connectionKey: connKey,
            topic: "sensors/living/temp",
            payload: "22.5",
            timestamp: Date(),
            extractFields: { _, _ in ["value": 22.5] }
        )

        let expectation = expectation(description: "wildcard match")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let results = self.store.query(forKey: key, since: 60)
            XCTAssertEqual(results.count, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Ordering

    func testResultsOrderedByTimestamp() {
        let now = Date()
        // Insert out of order
        store.append(points: [
            (storeKey: testKey, timestamp: now, field: "temperature", value: 23.0),
            (storeKey: testKey, timestamp: now.addingTimeInterval(-120), field: "temperature", value: 21.0),
            (storeKey: testKey, timestamp: now.addingTimeInterval(-60), field: "temperature", value: 22.0),
        ])

        let results = store.query(forKey: testKey, since: 300)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].value, 21.0)
        XCTAssertEqual(results[1].value, 22.0)
        XCTAssertEqual(results[2].value, 23.0)
    }
}
