import XCTest
@testable import IoTPanels

final class UnitFormatterTests: XCTestCase {

    // MARK: - Bytes Scaling

    func testBytesToGB() {
        let result = UnitFormatter.format(value: 5_307_109_376, unit: "B")
        XCTAssertEqual(result.unit, "GB")
        XCTAssertTrue(result.value.hasPrefix("4.9"), "Expected ~4.94, got \(result.value)")
    }

    func testBytesToMB() {
        let result = UnitFormatter.format(value: 2_097_152, unit: "B")
        XCTAssertEqual(result.unit, "MB")
        XCTAssertEqual(result.value, "2.00")
    }

    func testBytesToKB() {
        let result = UnitFormatter.format(value: 1024, unit: "B")
        XCTAssertEqual(result.unit, "KB")
        XCTAssertEqual(result.value, "1.00")
    }

    func testBytesToTB() {
        let result = UnitFormatter.format(value: 1_099_511_627_776, unit: "B")
        XCTAssertEqual(result.unit, "TB")
        XCTAssertEqual(result.value, "1.00")
    }

    func testSmallBytesStayAsBytes() {
        let result = UnitFormatter.format(value: 512, unit: "B")
        XCTAssertEqual(result.unit, "B")
        XCTAssertEqual(result.value, "512")
    }

    // MARK: - Watts Scaling

    func testWattsToKW() {
        let result = UnitFormatter.format(value: 1500, unit: "W")
        XCTAssertEqual(result.unit, "kW")
        XCTAssertEqual(result.value, "1.50")
    }

    func testMilliwattsToWatts() {
        let result = UnitFormatter.format(value: 2500, unit: "mW")
        XCTAssertEqual(result.unit, "W")
        XCTAssertEqual(result.value, "2.50")
    }

    // MARK: - Time Scaling

    func testSecondsToMinutes() {
        let result = UnitFormatter.format(value: 120, unit: "s")
        XCTAssertEqual(result.unit, "min")
        XCTAssertEqual(result.value, "2.00")
    }

    func testSecondsToDays() {
        let result = UnitFormatter.format(value: 86400, unit: "s")
        XCTAssertEqual(result.unit, "days")
        XCTAssertEqual(result.value, "1.00")
    }

    func testMillisecondsToSeconds() {
        let result = UnitFormatter.format(value: 5000, unit: "ms")
        XCTAssertEqual(result.unit, "s")
        XCTAssertEqual(result.value, "5.00")
    }

    // MARK: - Amps Scaling

    func testAmpsToMilliamps() {
        let result = UnitFormatter.format(value: 0.023, unit: "A")
        XCTAssertEqual(result.unit, "mA")
        XCTAssertEqual(result.value, "23.0")
    }

    // MARK: - Rate Units

    func testBytesPerSecond() {
        let result = UnitFormatter.format(value: 5_242_880, unit: "B/s")
        XCTAssertEqual(result.unit, "MB/s")
        XCTAssertEqual(result.value, "5.00")
    }

    // MARK: - Unknown Units

    func testUnknownUnit() {
        let result = UnitFormatter.format(value: 23.5, unit: "°C")
        XCTAssertEqual(result.unit, "°C")
        XCTAssertEqual(result.value, "23.5")
    }

    func testEmptyUnit() {
        let result = UnitFormatter.format(value: 42.1, unit: "")
        XCTAssertEqual(result.unit, "")
        XCTAssertEqual(result.value, "42.1")
    }

    // MARK: - Smart Decimal Places

    func testLargeValueNoDecimals() {
        XCTAssertEqual(UnitFormatter.smartFormat(512), "512")
    }

    func testMediumValueOneDecimal() {
        XCTAssertEqual(UnitFormatter.smartFormat(49.3), "49.3")
    }

    func testSmallValueTwoDecimals() {
        XCTAssertEqual(UnitFormatter.smartFormat(4.94), "4.94")
    }

    func testZeroValue() {
        XCTAssertEqual(UnitFormatter.smartFormat(0), "0")
    }

    // MARK: - Display String

    func testDisplayString() {
        let display = UnitFormatter.formatDisplay(value: 5_307_109_376, unit: "B")
        XCTAssertTrue(display.contains("GB"), "Expected GB in display: \(display)")
    }

    func testDisplayStringNoUnit() {
        let display = UnitFormatter.formatDisplay(value: 42, unit: "")
        XCTAssertEqual(display, "42")
    }
}
