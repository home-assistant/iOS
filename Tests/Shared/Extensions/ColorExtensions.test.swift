import Foundation
@testable import Shared
import SwiftUI
import Testing

@Suite("Color+hex Extensions Tests")
struct ColorHexExtensionsTests {
    @Test(
        "Given valid 6-character hex strings when initializing Color then creates correct color",
        arguments: [
            ("FF0000", 1.0, 0.0, 0.0, 1.0), // Red
            ("00FF00", 0.0, 1.0, 0.0, 1.0), // Green
            ("0000FF", 0.0, 0.0, 1.0, 1.0), // Blue
            ("FFFFFF", 1.0, 1.0, 1.0, 1.0), // White
            ("000000", 0.0, 0.0, 0.0, 1.0), // Black
            ("FF5733", 1.0, 0.341, 0.2, 1.0), // Orange
            ("3498DB", 0.204, 0.596, 0.859, 1.0), // Blue
            ("2ECC71", 0.180, 0.8, 0.443, 1.0), // Green
        ]
    )
    func validSixCharHexCreatesColor(hex: String, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) async throws {
        let color = Color(hex: hex)
        let uiColor = UIColor(color)

        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            Issue.record("Failed to get color components")
            return
        }

        let tolerance: CGFloat = 0.01
        #expect(abs(components[0] - r) < tolerance, "Red component should match")
        #expect(abs(components[1] - g) < tolerance, "Green component should match")
        #expect(abs(components[2] - b) < tolerance, "Blue component should match")

        if components.count >= 4 {
            #expect(abs(components[3] - a) < tolerance, "Alpha component should match")
        }
    }

    @Test(
        "Given valid 8-character hex strings with alpha when initializing Color then creates color with opacity",
        arguments: [
            ("FF0000FF", 1.0, 0.0, 0.0, 1.0), // Red, full opacity
            ("00FF0080", 0.0, 1.0, 0.0, 0.502), // Green, half opacity
            ("0000FF00", 0.0, 0.0, 1.0, 0.0), // Blue, transparent
            ("FFFFFF7F", 1.0, 1.0, 1.0, 0.498), // White, ~half opacity
        ]
    )
    func validEightCharHexWithAlphaCreatesColor(
        hex: String,
        r: CGFloat,
        g: CGFloat,
        b: CGFloat,
        a: CGFloat
    ) async throws {
        let color = Color(hex: hex)
        let uiColor = UIColor(color)

        guard let components = uiColor.cgColor.components, components.count >= 4 else {
            Issue.record("Failed to get color components with alpha")
            return
        }

        let tolerance: CGFloat = 0.01
        #expect(abs(components[0] - r) < tolerance, "Red component should match")
        #expect(abs(components[1] - g) < tolerance, "Green component should match")
        #expect(abs(components[2] - b) < tolerance, "Blue component should match")
        #expect(abs(components[3] - a) < tolerance, "Alpha component should match for \(hex)")
    }

    @Test(
        "Given invalid hex strings when initializing Color then falls back to default color",
        arguments: [
            "invalid",
            "GGGGGG",
            "12345", // Wrong length
            "1234567", // Wrong length
            "FFFFFFFFF", // Too long
            "ZZZ",
            "",
        ]
    )
    func invalidHexFallsBackToDefault(hex: String) async throws {
        let color = Color(hex: hex)
        // Should not crash and should create some color (fallback to haPrimary)
        let uiColor = UIColor(color)
        #expect(uiColor.cgColor.components != nil, "Should create a valid fallback color")
    }

    @Test("Given nil hex when initializing Color then falls back to default color")
    func nilHexFallsBackToDefault() async throws {
        let color = Color(hex: nil)
        let uiColor = UIColor(color)
        #expect(uiColor.cgColor.components != nil, "Should create a valid fallback color")
    }

    @Test("Given Color when converting to hex then returns correct hex string")
    func colorToHexConversion() async throws {
        let redColor = Color(red: 1.0, green: 0.0, blue: 0.0)
        let hex = redColor.hex()
        #expect(hex == "FF0000", "Red color should convert to FF0000")

        let blackColor = Color(red: 0.0, green: 0.0, blue: 0.0)
        let blackHex = blackColor.hex()
        #expect(blackHex == "000000", "Black color should convert to 000000")
    }

    @Test("Given Color with opacity when converting to hex then returns 8-character hex string")
    func colorWithOpacityToHexConversion() async throws {
        let redWithOpacity = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 0.5)
        let hex = redWithOpacity.hex()
        #expect(hex?.count == 8, "Color with opacity should return 8-character hex")
        #expect(hex?.hasPrefix("FF0000") == true, "Should start with red color code")
    }

    @Test("Given hex string when round-trip converting then preserves color")
    func hexRoundTripConversion() async throws {
        let originalHex = "3498DB"
        let color = Color(hex: originalHex)
        let convertedHex = color.hex()

        #expect(convertedHex == originalHex, "Round-trip conversion should preserve hex value")
    }

    @Test("Given hex string with alpha when round-trip converting then preserves color and opacity")
    func hexWithAlphaRoundTripConversion() async throws {
        let originalHex = "FF000080"
        let color = Color(hex: originalHex)
        let convertedHex = color.hex()

        #expect(convertedHex == originalHex, "Round-trip conversion with alpha should preserve hex value")
    }
}
