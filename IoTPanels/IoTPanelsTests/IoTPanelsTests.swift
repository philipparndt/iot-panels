import XCTest
@testable import IoTPanels

final class IoTPanelsTests: XCTestCase {
    func testBackendTypeRawValues() {
        XCTAssertEqual(BackendType.influxDB2.rawValue, "influxDB2")
    }

    func testBackendTypeDisplayName() {
        XCTAssertEqual(BackendType.influxDB2.displayName, "InfluxDB 2")
    }
}
