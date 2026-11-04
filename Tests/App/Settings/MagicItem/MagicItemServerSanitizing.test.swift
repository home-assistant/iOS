@testable import HomeAssistant
@testable import Shared
import Testing

/// Restoring configuration keeps only items whose server is signed in here, inside folders too.
struct MagicItemServerSanitizingTests {
    @Test func dropsUnknownServersItemsEvenInsideFolders() {
        var folder = MagicItem(id: "folder", serverId: "", type: .folder)
        folder.items = [
            MagicItem(id: "script.known", serverId: "known", type: .script),
            MagicItem(id: "script.gone", serverId: "gone", type: .script),
        ]
        let items = [
            folder,
            MagicItem(id: "light.known", serverId: "known", type: .entity),
            MagicItem(id: "light.gone", serverId: "gone", type: .entity),
        ]

        let sanitized = items.sanitized(knownServerIds: ["known"])

        #expect(sanitized.map(\.id) == ["folder", "light.known"])
        #expect(sanitized.first?.items?.map(\.id) == ["script.known"])
    }
}
