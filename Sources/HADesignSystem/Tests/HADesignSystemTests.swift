@testable import HADesignSystem
import SwiftUI
import XCTest

final class HADesignSystemTests: XCTestCase {
    func testSpacingScale() {
        XCTAssertEqual(DesignSystem.Spaces.one, 8)
        XCTAssertEqual(DesignSystem.Spaces.two, 16)
        XCTAssertEqual(DesignSystem.Spaces.six, 48)
    }

    func testCornerRadiusScale() {
        XCTAssertEqual(DesignSystem.CornerRadius.one, 8)
        XCTAssertEqual(HACornerRadius.standard, 8)
    }

    func testHexColorParsing() {
        XCTAssertEqual(Color(hex: "0xFF18BCF2"), Color.brandBlue)
    }

    func testSemanticColorsResolve() {
        XCTAssertNotNil(Color.haPrimary)
        XCTAssertNotNil(Color.onSurface)
        XCTAssertNotNil(Color.tileBorder)
    }
}
