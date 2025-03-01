import Foundation
@testable import HomeAssistant
import XCTest

class UIColorCSSRGBTests: XCTestCase {
    func testInvalidString() {
        XCTAssertNotColor("rgb()")
        XCTAssertNotColor("rgb(0, 0)")
        XCTAssertNotColor("rgba()")
        XCTAssertNotColor("rgba(0, 0)")
    }

    func testMixedCase() {
        XCTAssertNotNil(UIColor(rgbString: "RGB(90, 75, 66)"))
        XCTAssertNotNil(UIColor(rgbString: "Rgb(90, 75, 66)"))
        XCTAssertNotNil(UIColor(rgbString: "RGBA(90, 75, 66)"))
    }

    func testWeirdSpacing() {
        XCTAssertNotNil(UIColor(rgbString: "rgb(   90   ,   75   ,   66   )"))
        XCTAssertNotNil(UIColor(rgbString: "rgb(90,75,66)"))
        XCTAssertNotNil(UIColor(rgbString: "rgb (90,75,66)"))
        XCTAssertNotNil(UIColor(rgbString: "rgb(90,75,66) "))
        XCTAssertNotNil(UIColor(rgbString: " rgb(90,75,66)"))
        XCTAssertNotNil(UIColor(rgbString: "rgb(90 , 75 , 66)"))
    }

    func testBlack() {
        XCTAssertEqualColor("rgb(0, 0, 0)", 0, 0, 0, 1.0)
        XCTAssertEqualColor("rgba(0, 0, 0)", 0, 0, 0, 1.0)
        XCTAssertEqualColor("rgba(0, 0, 0, 0.25)", 0, 0, 0, 0.25)
    }

    func testWhite() {
        XCTAssertEqualColor("rgb(255, 255, 255)", 1, 1, 1, 1.0)
        XCTAssertEqualColor("rgba(255, 255, 255)", 1, 1, 1, 1.0)
        XCTAssertEqualColor("rgba(255, 255, 255, 0.25)", 1, 1, 1, 0.25)
    }

    func testMixed() {
        XCTAssertEqualColor("rgb(120, 164, 227)", 120.0 / 255.0, 164.0 / 255.0, 227.0 / 255.0, 1.0)
        XCTAssertEqualColor("rgba(120, 164, 227, 0.5)", 120.0 / 255.0, 164.0 / 255.0, 227.0 / 255.0, 0.5)
    }

    private func XCTAssertNotColor(_ string: String) {
        XCTAssertNil(UIColor(rgbString: string))
    }

    private func XCTAssertEqualColor(
        _ string: String,
        _ red: CGFloat,
        _ green: CGFloat,
        _ blue: CGFloat,
        _ alpha: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let color = UIColor(rgbString: string) else {
            XCTFail("couldn't create color from \(string)")
            return
        }

        var colorRed: CGFloat = -1, colorGreen: CGFloat = -1, colorBlue: CGFloat = -1, colorAlpha: CGFloat = -1
        XCTAssertTrue(
            color.getRed(&colorRed, green: &colorGreen, blue: &colorBlue, alpha: &colorAlpha),
            file: file,
            line: line
        )
        XCTAssertEqual(colorRed, red, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(colorGreen, green, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(colorBlue, blue, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(colorAlpha, alpha, accuracy: 0.01, file: file, line: line)
    }
}
