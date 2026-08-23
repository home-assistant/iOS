@testable import Shared
import Testing

/// Coverage for how the watch's area screen splits a section's entities into loose rows and
/// per-device sections.
struct WatchGroupedEntitiesTests {
    @Test("Only devices contributing more than one entity get their own section")
    func groupsDevicesWithSeveralEntities() {
        let grouped = WatchGroupedEntities.make([
            entry("light.lamp", device: .init(id: "lamp", name: "Lamp")),
            entry("switch.lamp_led", device: .init(id: "lamp", name: "Lamp")),
            // A device with a single entity here reads better as a loose row than as a one-row
            // section, so it stays ungrouped…
            entry("light.ceiling", device: .init(id: "ceiling", name: "Ceiling")),
            // …and so does an entity the registry attributes to no device at all.
            entry("input_boolean.guest_mode"),
        ])

        #expect(grouped.ungrouped.map(\.item.id) == ["light.ceiling", "input_boolean.guest_mode"])
        #expect(grouped.deviceGroups.map(\.deviceId) == ["lamp"])
        #expect(grouped.deviceGroups.first?.name == "Lamp")
        #expect(grouped.deviceGroups.first?.entries.map(\.item.id) == ["light.lamp", "switch.lamp_led"])
    }

    @Test("Grouping keeps the caller's order and sorts the sections by device name")
    func preservesOrderWithinGroupsAndSortsGroups() {
        let grouped = WatchGroupedEntities.make([
            entry("light.zulu_two", device: .init(id: "zulu", name: "Zulu")),
            entry("light.alpha_two", device: .init(id: "alpha", name: "alpha")),
            entry("light.zulu_one", device: .init(id: "zulu", name: "Zulu")),
            entry("light.alpha_one", device: .init(id: "alpha", name: "alpha")),
        ])

        // Case-insensitive, so "alpha" precedes "Zulu"…
        #expect(grouped.deviceGroups.map(\.name) == ["alpha", "Zulu"])
        // …while the entities inside each section stay in the order the section was sorted in.
        #expect(grouped.deviceGroups.first?.entries.map(\.item.id) == ["light.alpha_two", "light.alpha_one"])
        #expect(grouped.allEntries.count == 4)
    }

    @Test("Nothing to group yields an empty result")
    func emptyInputIsEmpty() {
        #expect(WatchGroupedEntities.make([]).isEmpty)
        #expect(WatchGroupedEntities.empty.isEmpty)
    }

    private func entry(_ entityId: String, device: WatchEntityEntry.Device? = nil) -> WatchEntityEntry {
        .init(
            item: .init(id: entityId, serverId: "1", type: .entity),
            info: .init(id: "1-\(entityId)", name: entityId, iconName: "mdi:lightbulb"),
            device: device
        )
    }
}
