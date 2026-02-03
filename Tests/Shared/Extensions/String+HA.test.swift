import Foundation
@testable import Shared
import Testing

@Suite("String+HA Extensions Tests")
struct StringHAExtensionsTests {
    // MARK: - djb2hash Tests

    @Test("Given empty string when getting djb2hash then returns base hash")
    func djb2hashEmptyString() async throws {
        let emptyString = ""
        #expect(emptyString.djb2hash == 5381, "Empty string should return base hash value 5381")
    }

    @Test(
        "Given identical strings when getting djb2hash then returns same hash",
        arguments: [
            "test",
            "home_assistant",
            "entity.light.living_room",
            "Hello World!",
            "🏠",
        ]
    )
    func djb2hashConsistency(input: String) async throws {
        let hash1 = input.djb2hash
        let hash2 = input.djb2hash
        #expect(hash1 == hash2, "Hash should be consistent for '\(input)'")
    }

    @Test("Given different strings when getting djb2hash then returns different hashes")
    func djb2hashDifferentStrings() async throws {
        let string1 = "test1"
        let string2 = "test2"
        let string3 = "completely different"

        #expect(string1.djb2hash != string2.djb2hash, "Different strings should produce different hashes")
        #expect(string1.djb2hash != string3.djb2hash, "Different strings should produce different hashes")
        #expect(string2.djb2hash != string3.djb2hash, "Different strings should produce different hashes")
    }

    @Test("Given string with unicode characters when getting djb2hash then returns valid hash")
    func djb2hashUnicodeCharacters() async throws {
        let unicode1 = "Hello 世界"
        let unicode2 = "🏠🔒🔑"
        let unicode3 = "Café"

        // Verify hashes are generated without crashing
        let hash1 = unicode1.djb2hash
        let hash2 = unicode2.djb2hash
        let hash3 = unicode3.djb2hash

        // Hashes should be different for different strings
        #expect(hash1 != hash2, "Different unicode strings should produce different hashes")
        #expect(hash2 != hash3, "Different unicode strings should produce different hashes")
    }

    @Test("Given very long string when getting djb2hash then returns valid hash")
    func djb2hashLongString() async throws {
        let longString = String(repeating: "a", count: 10000)
        let hash = longString.djb2hash
        #expect(hash != 5381, "Long string should produce hash different from base value")
    }

    // MARK: - containsJinjaTemplate Tests

    @Test(
        "Given strings with Jinja templates when checking containsJinjaTemplate then returns true",
        arguments: [
            "{{ state.temperature }}",
            "Value: {{ sensor.value }}",
            "{% if condition %}text{% endif %}",
            "Start {% for item in items %} loop",
            "{# This is a comment #}",
            "Mixed {{ variable }} and {% statement %}",
            "Multiple {{ var1 }} {{ var2 }} templates",
            "{{no_space}}",
            "{%no_space%}",
            "{#no_space#}",
        ]
    )
    func containsJinjaTemplateTrue(input: String) async throws {
        #expect(input.containsJinjaTemplate == true, "'\(input)' should contain Jinja template")
    }

    @Test(
        "Given strings without Jinja templates when checking containsJinjaTemplate then returns false",
        arguments: [
            "plain text",
            "{ single brace }",
            "% percent sign %",
            "# hashtag",
            "regular JSON {\"key\": \"value\"}",
            "",
            "{ { space between }}",
            "{% space before",
            "after space %}",
            "{{",
            "{%",
            "{#",
        ]
    )
    func containsJinjaTemplateFalse(input: String) async throws {
        #expect(input.containsJinjaTemplate == false, "'\(input)' should not contain Jinja template")
    }

    @Test("Given string with incomplete Jinja syntax when checking containsJinjaTemplate")
    func containsJinjaTemplateIncomplete() async throws {
        // These have the opening but are still considered to contain Jinja templates
        #expect("{{ unclosed".containsJinjaTemplate == true, "String with {{ should be detected")
        #expect("{% unclosed".containsJinjaTemplate == true, "String with {% should be detected")
        #expect("{# unclosed".containsJinjaTemplate == true, "String with {# should be detected")
    }

    // MARK: - capitalizedFirst Tests

    @Test(
        "Given string when getting capitalizedFirst then capitalizes first character",
        arguments: [
            ("hello", "Hello"),
            ("world", "World"),
            ("test", "Test"),
            ("a", "A"),
            ("already Capitalized", "Already Capitalized"),
        ]
    )
    func capitalizedFirst(input: String, expected: String) async throws {
        #expect(input.capitalizedFirst == expected, "'\(input)' should become '\(expected)'")
    }

    @Test("Given empty string when getting capitalizedFirst then returns empty string")
    func capitalizedFirstEmptyString() async throws {
        let empty = ""
        #expect(empty.capitalizedFirst == "", "Empty string should remain empty")
    }

    @Test("Given string with special characters when getting capitalizedFirst then handles correctly")
    func capitalizedFirstSpecialCharacters() async throws {
        let unicode = "éllo"
        #expect(unicode.capitalizedFirst == "Éllo", "Unicode character should be capitalized")
    }

    // MARK: - formattedBSSID Tests

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
            "no:colons:just:text",
            "12:34", // Only 2 octets
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

    @Test("Given BSSID with three-character octets when formatted then preserves as-is")
    func bssidFormattingWithThreeCharacterOctets() async throws {
        let invalid = "111:222:333:444:555:666"
        #expect(
            invalid.formattedBSSID == "111:222:333:444:555:666",
            "BSSID with 3-character octets should be returned unchanged"
        )
    }

    // MARK: - String? orEmpty Tests

    @Test("Given nil string when getting orEmpty then returns empty string")
    func orEmptyWithNil() async throws {
        let nilString: String? = nil
        #expect(nilString.orEmpty == "", "nil string should return empty string")
    }

    @Test(
        "Given non-nil string when getting orEmpty then returns original string",
        arguments: [
            "hello",
            "world",
            "",
            "   ",
            "test string",
            "🏠",
        ]
    )
    func orEmptyWithNonNil(input: String) async throws {
        let optionalString: String? = input
        #expect(optionalString.orEmpty == input, "Non-nil string should return original value")
    }
}
