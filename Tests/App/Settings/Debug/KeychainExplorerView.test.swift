@testable import HomeAssistant
import Security
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Seeds generic password items whose service sorts first, lays the keychain explorer out and opens
/// each seeded item, so the JSON, plain text and binary renderings all run.
///
/// `.sharedState`: the test writes the keychain.
@Suite(.sharedState)
@MainActor
struct KeychainExplorerViewTests {
    /// "!" sorts before every letter and digit, so these items make up the first section.
    private static let service = "!ha-tests-keychain-explorer"

    private func add(account: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func removeSeededItems() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
        ]
        SecItemDelete(query as CFDictionary)
    }

    @Test func listsAndOpensEverySeededItem() async throws {
        defer { removeSeededItems() }
        add(account: "a-json", data: Data(#"{"token":"abc","expires":3600}"#.utf8))
        add(account: "b-text", data: Data("  first line\nsecond line  ".utf8))
        add(account: "c-binary", data: Data([0xFF, 0xFE, 0x00, 0x81]))
        add(account: "d-whitespace", data: Data("   ".utf8))

        let harness = await SettingsScreenHarness.show(KeychainExplorerView())
        await #expect(harness.waitUntil { harness.rows.count >= 4 })

        let seeded = harness.rows.filter { $0.section == 0 }
        #expect(seeded.count >= 4)
        var opened = 0
        for row in seeded {
            if await harness.push(row) {
                opened += 1
                await harness.pop()
            }
        }
        #expect(opened == seeded.count)
        #expect(harness.depth == 1)
        await harness.close()
    }
}
