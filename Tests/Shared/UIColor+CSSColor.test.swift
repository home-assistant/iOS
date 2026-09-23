@testable import Shared
import UIKit
import XCTest

final class UIColorCSSColorTests: XCTestCase {
    func testParsesCommaSeparatedRGB() {
        assertComponents("rgb(3, 169, 244)", red: 3 / 255, green: 169 / 255, blue: 244 / 255, alpha: 1)
    }

    func testParsesRGBAWithAlpha() {
        assertComponents("rgba(0, 0, 0, 0.12)", red: 0, green: 0, blue: 0, alpha: 0.12)
    }

    func testParsesSpaceSeparatedModernSyntax() {
        assertComponents("rgb(3 169 244 / 0.5)", red: 3 / 255, green: 169 / 255, blue: 244 / 255, alpha: 0.5)
    }

    func testParsesPercentageChannelsAndAlphaIndependently() {
        assertComponents("rgb(100%, 0%, 50%)", red: 1, green: 0, blue: 0.5, alpha: 1)
        // A percentage alpha alongside numeric channels must not make the channels percentages too.
        assertComponents("rgba(255, 0, 0, 50%)", red: 1, green: 0, blue: 0, alpha: 0.5)
    }

    func testParsesHex() {
        assertComponents("#ff9800", red: 1, green: 0x98 / 255, blue: 0, alpha: 1)
    }

    func testTransparentKeywordIsFullyClear() {
        assertComponents("transparent", red: 0, green: 0, blue: 0, alpha: 0)
    }

    func testTrimsSurroundingWhitespace() {
        assertComponents("  rgb(255, 255, 255)\n", red: 1, green: 1, blue: 1, alpha: 1)
    }

    func testClampsOutOfRangeComponents() {
        assertComponents("rgba(300, -20, 0, 1.5)", red: 1, green: 0, blue: 0, alpha: 1)
    }

    func testRejectsNonColorValues() {
        // Theme variables are not all colours; a length has to come back nil rather than as black.
        XCTAssertNil(UIColor(cssColorString: "8px"))
        XCTAssertNil(UIColor(cssColorString: ""))
        XCTAssertNil(UIColor(cssColorString: "  "))
        XCTAssertNil(UIColor(cssColorString: "rgb(1, 2)"))
        XCTAssertNil(UIColor(cssColorString: "var(--primary-color)"))
    }

    private func assertComponents(
        _ value: String,
        red expectedRed: CGFloat,
        green expectedGreen: CGFloat,
        blue expectedBlue: CGFloat,
        alpha expectedAlpha: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let color = UIColor(cssColorString: value) else {
            XCTFail("Expected \(value) to parse as a colour", file: file, line: line)
            return
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual(red, expectedRed, accuracy: 0.001, "red of \(value)", file: file, line: line)
        XCTAssertEqual(green, expectedGreen, accuracy: 0.001, "green of \(value)", file: file, line: line)
        XCTAssertEqual(blue, expectedBlue, accuracy: 0.001, "blue of \(value)", file: file, line: line)
        XCTAssertEqual(alpha, expectedAlpha, accuracy: 0.001, "alpha of \(value)", file: file, line: line)
    }
}
