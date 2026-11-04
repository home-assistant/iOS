@testable import Shared
import SwiftUI
import UIKit
import XCTest

final class ColorHexTests: XCTestCase {
    private struct RGBA: Equatable {
        let r, g, b, a: Int
    }

    private func components(_ color: UIColor) -> RGBA {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBA(
            r: Int((red * 255).rounded()),
            g: Int((green * 255).rounded()),
            b: Int((blue * 255).rounded()),
            a: Int((alpha * 255).rounded())
        )
    }

    func testSixDigitHex() throws {
        let color = try XCTUnwrap(UIColor(rgbaString: "#FF8800"))
        XCTAssertEqual(components(color).r, 255)
        XCTAssertEqual(components(color).g, 136)
        XCTAssertEqual(components(color).b, 0)
        XCTAssertEqual(components(color).a, 255)
    }

    func testEightDigitHexParsesAlpha() throws {
        let color = try XCTUnwrap(UIColor(rgbaString: "#FF880080"))
        XCTAssertEqual(components(color).a, 128)
    }

    func testThreeDigitShorthandExpands() throws {
        let shorthand = try XCTUnwrap(UIColor(rgbaString: "#F80"))
        XCTAssertEqual(components(shorthand), components(UIColor(rgbaString: "#FF8800")!))
    }

    func testFourDigitShorthandExpands() throws {
        let color = try XCTUnwrap(UIColor(rgbaString: "#F808"))
        XCTAssertEqual(components(color).r, 255)
        XCTAssertEqual(components(color).g, 136)
        XCTAssertEqual(components(color).b, 0)
        XCTAssertEqual(components(color).a, 136)
    }

    func testMissingHashIsNil() {
        XCTAssertNil(UIColor(rgbaString: "FF8800"))
    }

    func testTrailingInvalidCharactersAreNil() {
        XCTAssertNil(UIColor(rgbaString: "#123xyz"))
    }

    func testUnsupportedLengthIsNil() {
        XCTAssertNil(UIColor(rgbaString: "#12345"))
    }

    func testUnlabeledInitParsesValidString() {
        XCTAssertEqual(components(UIColor("#00FF00")).g, 255)
    }

    func testUnlabeledInitFallsBackToDefaultColor() {
        XCTAssertEqual(components(UIColor("not-a-color", defaultColor: .red)), components(.red))
    }

    func testHexStringIncludesAlphaByDefault() {
        XCTAssertEqual(UIColor(red: 1, green: 0, blue: 0, alpha: 1).hexString(), "#FF0000FF")
    }

    func testHexStringWithoutAlpha() {
        XCTAssertEqual(UIColor(red: 1, green: 0, blue: 0, alpha: 1).hexString(false), "#FF0000")
    }

    func testHexStringRoundTrip() throws {
        let color = try XCTUnwrap(UIColor(rgbaString: "#FF8800"))
        XCTAssertEqual(color.hexString(false), "#FF8800")
    }

    func testColorHexInit() {
        XCTAssertEqual(components(UIColor(Color(hex: "#0000FF"))).b, 255)
    }

    func testColorHexInitPrependsHash() {
        XCTAssertEqual(
            components(UIColor(Color(hex: "00FF00"))),
            components(UIColor(Color(hex: "#00FF00")))
        )
    }

    func testColorHexInvalidIsClear() {
        XCTAssertEqual(components(UIColor(Color(hex: "zzz"))).a, 0)
    }
}
