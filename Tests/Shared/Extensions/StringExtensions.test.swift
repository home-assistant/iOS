import Foundation
@testable import Shared
import Testing

@Suite("String Extensions Tests")
struct StringExtensionsTests {
    @Test(
        "Given BSSID with single-digit hex values when formatted then adds leading zeros",
        arguments: [
            ("18:e8:29:a7:e9:b", "18:e8:29:a7:e9:0b"),
            ("a:b:c:d:e:f", "0a:0b:0c:0d:0e:0f"),
            ("1:2:3:4:5:6", "01:02:03:04:05:06"),
            ("aa:bb:cc:dd:ee:f", "aa:bb:cc:dd:ee:0f"),
            ("1:bb:c:dd:e:ff", "01:bb:0c:dd:0e:ff"),
        ]
    )
    func bssidFormattingAddsLeadingZeros(input: String, expected: String) async throws {
        #expect(input.formattedBSSID == expected, "BSSID \(input) should be formatted as \(expected)")
    }

    @Test(
        "Given BSSID with all two-digit hex values when formatted then remains unchanged",
        arguments: [
            "18:e8:29:a7:e9:0b",
            "ff:ee:dd:cc:bb:aa",
            "aa:bb:cc:dd:ee:ff",
            "12:34:56:78:9a:bc",
        ]
    )
    func bssidFormattingPreservesFullValues(input: String) async throws {
        #expect(input.formattedBSSID == input, "BSSID \(input) should remain unchanged")
    }

    @Test(
        "Given invalid MAC address formats when formatted then returns unchanged",
        arguments: [
            "not-a-mac",
            "18:e8:29:a7:e9", // Too few octets
            "18:e8:29:a7:e9:0b:aa", // Too many octets
            "", // Empty string
            "invalid:format:here",
        ]
    )
    func bssidFormattingHandlesInvalidFormats(input: String) async throws {
        #expect(
            input.formattedBSSID == input,
            "Invalid MAC address \(input) should be returned unchanged"
        )
    }

    @Test("Given uppercase BSSID when formatted then preserves case")
    func bssidFormattingPreservesCase() async throws {
        let uppercase = "AA:BB:CC:DD:EE:F"
        let expectedUppercase = "AA:BB:CC:DD:EE:0F"
        #expect(
            uppercase.formattedBSSID == expectedUppercase,
            "Uppercase BSSID should be formatted with preserved case"
        )

        let lowercase = "aa:bb:cc:dd:ee:f"
        let expectedLowercase = "aa:bb:cc:dd:ee:0f"
        #expect(
            lowercase.formattedBSSID == expectedLowercase,
            "Lowercase BSSID should be formatted with preserved case"
        )

        let mixed = "aA:bB:cC:dD:eE:Ff"
        let expectedMixed = "aA:bB:cC:dD:eE:Ff"
        #expect(mixed.formattedBSSID == expectedMixed, "Mixed case BSSID should be formatted with preserved case")
    }
}
