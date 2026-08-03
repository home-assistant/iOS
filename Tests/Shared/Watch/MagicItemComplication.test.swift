import GRDB
@testable import Shared
import Testing

@Suite(.serialized)
struct MagicItemComplicationTests {
    @Test("Only rectangular complications are offered for the watch item list")
    func onlyRectangularIsAddable() throws {
        try withComplications([
            config(id: "rect", widgetFamily: .rectangular, name: "Rectangular"),
            config(id: "circ", widgetFamily: .circular, name: "Circular"),
            config(id: "inline", widgetFamily: .inline, name: "Inline"),
            config(id: "corner", widgetFamily: .corner, name: "Corner"),
        ]) {
            let addable = try WatchComplicationConfig.watchListAddable()
            #expect(addable.map(\.id) == ["rect"])
        }
    }

    @Test("A complication item carries the config's identity and never runs anything")
    func itemMirrorsConfig() {
        let config = config(
            id: "config-id",
            widgetFamily: .rectangular,
            name: "Solar",
            iconName: "mdi:solar-power",
            iconColor: "#FFCC00"
        )
        let item = MagicItem(complication: config)

        #expect(item.id == "config-id")
        #expect(item.serverId == "server-1")
        #expect(item.type == .complication)
        #expect(item.customization?.iconColor == "#FFCC00")
        // Left to `icon(info:)`, which normalizes the server-side "mdi:" name the config stores.
        #expect(item.customization?.icon == nil)
        // Nothing happens on tap, so a confirmation would be asking about nothing.
        #expect(item.customization?.requiresConfirmation == false)
        #expect(item.action == .nothing)
    }

    @Test("Info resolves the complication's name, and drops the item once its config is gone")
    func infoResolvesFromConfig() throws {
        try withComplications([
            config(
                id: "config-id",
                widgetFamily: .rectangular,
                name: "Battery",
                entityId: "sensor.battery",
                entityDisplayName: "Phone battery",
                iconName: "mdi:battery"
            ),
        ]) {
            let provider = MagicItemProvider()
            let item = MagicItem(id: "config-id", serverId: "server-1", type: .complication)
            let info = provider.getInfo(for: item)

            #expect(info?.id == "server-1-config-id")
            #expect(info?.name == "Battery")
            #expect(info?.iconName == "mdi:battery")
            #expect(info?.contextSubtitle == "Phone battery")

            let missing = MagicItem(id: "deleted", serverId: "server-1", type: .complication)
            #expect(provider.getInfo(for: missing) == nil)
        }
    }

    // MARK: - Helpers

    private func config(
        id: String,
        widgetFamily: WatchComplicationConfig.Family,
        name: String,
        entityId: String? = nil,
        entityDisplayName: String? = nil,
        iconName: String? = nil,
        iconColor: String? = nil
    ) -> WatchComplicationConfig {
        WatchComplicationConfig(
            id: id,
            serverId: "server-1",
            widgetFamily: widgetFamily,
            name: name,
            entityId: entityId,
            entityDisplayName: entityDisplayName,
            iconName: iconName,
            iconColor: iconColor
        )
    }

    private func withComplications(
        _ configs: [WatchComplicationConfig],
        perform work: () throws -> Void
    ) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try WatchComplicationConfigTable().createIfNeeded(database: database)
        try database.write { db in
            for config in configs {
                try config.insert(db)
            }
        }
        Current.database = { database }
        defer { Current.database = previousDatabase }

        try work()
    }
}
