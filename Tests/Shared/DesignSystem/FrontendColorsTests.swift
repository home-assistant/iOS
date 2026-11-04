@testable import Shared
import SwiftUI
import Testing
import UIKit

struct FrontendColorsTests {
    @Test func rawValuesMatchCSSProperties() {
        #expect(FrontendColors.redColor.rawValue == "--red-color")
        #expect(FrontendColors(rawValue: "--red-color") == .redColor)
        #expect(FrontendColors.allCases.count > 200)
    }

    @Test func lightAndDarkRawValues() {
        #expect(FrontendColors.redColor.lightValue == "#f44336")
        #expect(FrontendColors.primaryBackgroundColor.lightValue == "#fafafa")
        #expect(FrontendColors.primaryBackgroundColor.darkValue == "#111111")
        // A light-only variable has no dark override.
        #expect(FrontendColors.redColor.darkValue == nil)
    }

    @Test func resolvesHexLiteral() throws {
        let color = try #require(rgba(FrontendColors.redColor.lightColor))
        expectClose(color, red: 244 / 255, green: 67 / 255, blue: 54 / 255, alpha: 1)
    }

    @Test func resolvesVariableReference() throws {
        // --state-light-active-color: var(--amber-color); --amber-color: #ffc107
        let color = try #require(rgba(FrontendColors.stateLightActiveColor.lightColor))
        expectClose(color, red: 255 / 255, green: 193 / 255, blue: 7 / 255, alpha: 1)
    }

    @Test func resolvesVariableFallback() throws {
        // --state-unavailable-color references an undefined property, so the
        // fallback var(--disabled-text-color) (#bdbdbd) should win.
        let color = try #require(rgba(FrontendColors.stateUnavailableColor.lightColor))
        expectClose(color, red: 189 / 255, green: 189 / 255, blue: 189 / 255, alpha: 1)
    }

    @Test func resolvesRGBAFunction() throws {
        // --divider-color (dark): rgba(225, 225, 225, 0.12)
        let color = try #require(rgba(FrontendColors.dividerColor.darkColor))
        expectClose(color, red: 225 / 255, green: 225 / 255, blue: 225 / 255, alpha: 0.12)
    }

    @Test func externalReferencesAreUnresolved() {
        // --primary-color: var(--ha-color-primary-40) lives in core.globals.
        #expect(FrontendColors.primaryColor.lightColor == nil)
    }

    private func rgba(_ color: Color?) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        guard let color else { return nil }
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
    }

    private func expectClose(
        _ color: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat),
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat,
        tolerance: CGFloat = 0.01
    ) {
        #expect(abs(color.r - red) < tolerance)
        #expect(abs(color.g - green) < tolerance)
        #expect(abs(color.b - blue) < tolerance)
        #expect(abs(color.a - alpha) < tolerance)
    }
}
