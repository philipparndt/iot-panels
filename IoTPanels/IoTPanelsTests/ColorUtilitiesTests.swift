import SwiftUI
import XCTest
@testable import IoTPanels

final class ColorUtilitiesTests: XCTestCase {

    // MARK: - init(hex:)

    func testHexInitRed() {
        let c = Color(hex: "#FF0000").resolve(in: EnvironmentValues())
        XCTAssertEqual(c.red, 1, accuracy: 0.001)
        XCTAssertEqual(c.green, 0, accuracy: 0.001)
        XCTAssertEqual(c.blue, 0, accuracy: 0.001)
    }

    func testHexInitGreen() {
        let c = Color(hex: "#00FF00").resolve(in: EnvironmentValues())
        XCTAssertEqual(c.red, 0, accuracy: 0.001)
        XCTAssertEqual(c.green, 1, accuracy: 0.001)
        XCTAssertEqual(c.blue, 0, accuracy: 0.001)
    }

    func testHexInitBlue() {
        let c = Color(hex: "#0000FF").resolve(in: EnvironmentValues())
        XCTAssertEqual(c.red, 0, accuracy: 0.001)
        XCTAssertEqual(c.green, 0, accuracy: 0.001)
        XCTAssertEqual(c.blue, 1, accuracy: 0.001)
    }

    func testHexInitGrey() {
        let c = Color(hex: "#808080").resolve(in: EnvironmentValues())
        XCTAssertEqual(c.red, 128.0 / 255.0, accuracy: 0.005)
        XCTAssertEqual(c.green, 128.0 / 255.0, accuracy: 0.005)
        XCTAssertEqual(c.blue, 128.0 / 255.0, accuracy: 0.005)
    }

    func testHexInitPaletteBlue() {
        // SeriesColors.palette entry "#4A90D9"
        let c = Color(hex: "#4A90D9").resolve(in: EnvironmentValues())
        XCTAssertEqual(c.red, 0x4A / 255.0, accuracy: 0.005)
        XCTAssertEqual(c.green, 0x90 / 255.0, accuracy: 0.005)
        XCTAssertEqual(c.blue, 0xD9 / 255.0, accuracy: 0.005)
    }

    // MARK: - complementary()

    func testComplementaryRedIsCyan() {
        let comp = Color(hex: "#FF0000").complementary().resolve(in: EnvironmentValues())
        XCTAssertEqual(comp.red, 0, accuracy: 0.01)
        XCTAssertEqual(comp.green, 1, accuracy: 0.01)
        XCTAssertEqual(comp.blue, 1, accuracy: 0.01)
    }

    func testComplementaryGreenIsMagenta() {
        let comp = Color(hex: "#00FF00").complementary().resolve(in: EnvironmentValues())
        XCTAssertEqual(comp.red, 1, accuracy: 0.01)
        XCTAssertEqual(comp.green, 0, accuracy: 0.01)
        XCTAssertEqual(comp.blue, 1, accuracy: 0.01)
    }

    func testComplementaryBlueIsYellow() {
        let comp = Color(hex: "#0000FF").complementary().resolve(in: EnvironmentValues())
        XCTAssertEqual(comp.red, 1, accuracy: 0.01)
        XCTAssertEqual(comp.green, 1, accuracy: 0.01)
        XCTAssertEqual(comp.blue, 0, accuracy: 0.01)
    }

    func testComplementaryGreyStaysGrey() {
        // Grey has zero saturation — complementary is the same grey.
        let comp = Color(hex: "#808080").complementary().resolve(in: EnvironmentValues())
        XCTAssertEqual(comp.red, 128.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(comp.green, 128.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(comp.blue, 128.0 / 255.0, accuracy: 0.01)
    }

    func testComplementaryPaletteOrange() {
        // SeriesColors palette "#F39C12" → complement is a bluish hue
        let comp = Color(hex: "#F39C12").complementary().resolve(in: EnvironmentValues())
        // Orange's complement has more blue than red.
        XCTAssertGreaterThan(comp.blue, comp.red)
    }
}
