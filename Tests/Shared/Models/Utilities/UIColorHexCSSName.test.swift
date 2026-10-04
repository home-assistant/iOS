@testable import Shared
import UIKit
import XCTest

final class UIColorHexCSSNameTests: XCTestCase {
    private func rgba(_ color: UIColor) -> [Int] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }

    func testNilAndEmptyAreClear() {
        XCTAssertEqual(rgba(UIColor(hex: nil)), [0, 0, 0, 0])
        XCTAssertEqual(rgba(UIColor(hex: "")), [0, 0, 0, 0])
        XCTAssertEqual(rgba(UIColor(hex: "Clear")), [0, 0, 0, 0])
        XCTAssertEqual(rgba(UIColor(hex: "transparent")), [0, 0, 0, 0])
    }

    func testCSSNamesAreCaseInsensitive() {
        XCTAssertEqual(rgba(UIColor(hex: "Tomato")), [0xFF, 0x63, 0x47, 0xFF])
        XCTAssertEqual(rgba(UIColor(hex: "AZURE")), [0xF0, 0xFF, 0xFF, 0xFF])
        XCTAssertEqual(rgba(UIColor(hex: "black")), [0, 0, 0, 0xFF])
    }

    func testShorthandHexExpands() {
        XCTAssertEqual(rgba(UIColor(hex: "abc")), [0xAA, 0xBB, 0xCC, 0xFF])
        XCTAssertEqual(rgba(UIColor(hex: "#abc7")), [0xAA, 0xBB, 0xCC, 0x77])
    }

    func testFullHexWithAndWithoutAlpha() {
        XCTAssertEqual(rgba(UIColor(hex: "#00FFFF")), [0x00, 0xFF, 0xFF, 0xFF])
        XCTAssertEqual(rgba(UIColor(hex: "00FFFF77")), [0x00, 0xFF, 0xFF, 0x77])
    }
}
