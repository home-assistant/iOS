import Foundation
@testable import Shared
import Testing

struct MagicItemAreaEntryTests {
    private func info(iconName: String) -> MagicItem.Info {
        .init(id: "1-living_room", name: "Living Room", iconName: iconName)
    }

    /// `ItemType` raw values are persisted in the watch configuration, so the area entry has to keep
    /// encoding — and decoding — as "area" rather than falling back to `.unsupported`.
    @Test func encodesAndDecodesItsPersistedRawValue() throws {
        let item = MagicItem(id: "living_room", serverId: "1", type: .area)
        let data = try JSONEncoder().encode(item)

        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["type"] as? String == "area")

        let decoded = try JSONDecoder().decode(MagicItem.self, from: data)
        #expect(decoded.type == .area)
        #expect(decoded.serverUniqueId == "1-living_room")
    }

    @Test func usesTheAreaIconAndFallsBackToTheAreaSymbol() {
        let item = MagicItem(id: "living_room", serverId: "1", type: .area)
        #expect(item.icon(info: info(iconName: "mdi:sofa")) == MaterialDesignIcons.sofaIcon)
        // Areas without an icon of their own get the same one the automatic area rows use.
        #expect(item.icon(info: info(iconName: "")) == MaterialDesignIcons.textureBoxIcon)
    }

    @Test func customIconStillWins() {
        let item = MagicItem(
            id: "living_room",
            serverId: "1",
            type: .area,
            customization: .init(icon: MaterialDesignIcons.lightbulbIcon.name)
        )
        #expect(item.icon(info: info(iconName: "mdi:sofa")) == MaterialDesignIcons.lightbulbIcon)
    }

    /// An area entry opens the area's entities; it never runs anything, so it has no domain to
    /// resolve an action from.
    @Test func hasNoDomainToExecute() {
        let item = MagicItem(id: "living_room", serverId: "1", type: .area)
        #expect(item.domain == nil)
        #expect(!item.isWatchDisplayOnly)
    }
}
