@testable import Shared
import SwiftUI
import XCTest

/// Covers `Color(hex: String?)` and `Color.hex()` from `Shared`. Passing a `String?` keeps the
/// call off the design system's non-optional `Color(hex: String)` overload.
final class ColorOptionalHexTests: XCTestCase {
    private static let fallbackHex = "009AC7"

    private func color(_ hex: String?) -> Color {
        Color(hex: hex)
    }

    func testSixDigitHexRoundTrips() {
        XCTAssertEqual(color("#FF8800").hex(), "FF8800")
        XCTAssertEqual(color("  00ff7f\n").hex(), "00FF7F")
    }

    func testEightDigitHexKeepsAlpha() {
        XCTAssertEqual(color("FF880080").hex(), "FF880080")
    }

    func testNilFallsBackToPrimary() {
        XCTAssertEqual(color(nil).hex(), Self.fallbackHex)
    }

    func testUnparsableHexFallsBackToPrimary() {
        XCTAssertEqual(color("zzzzzz").hex(), Self.fallbackHex)
    }

    func testUnsupportedLengthFallsBackToPrimary() {
        XCTAssertEqual(color("FFF").hex(), Self.fallbackHex)
        XCTAssertEqual(color("FFFFFFF").hex(), Self.fallbackHex)
    }

    func testHexOfGrayscaleColor() {
        XCTAssertEqual(Color.white.hex(), "FFFFFF")
        XCTAssertEqual(Color.black.hex(), "000000")
    }

    func testHexOfTranslucentColorIncludesAlpha() {
        XCTAssertEqual(Color(red: 1, green: 0, blue: 0, opacity: 0.5).hex(), "FF000080")
    }
}
