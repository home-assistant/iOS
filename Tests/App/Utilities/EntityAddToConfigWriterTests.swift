import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct EntityAddToConfigWriterTests {
    @Test("Adding to the watch stores the entity and stamps the config")
    func addsToWatch() throws {
        try withConfigDatabase {
            let outcome = try EntityAddToConfigWriter.add(
                entityId: "light.kitchen",
                serverId: "1",
                to: .appleWatch
            )

            #expect(outcome == .added)
            let config = try #require(WatchConfig.config())
            #expect(config.items.map(\.id) == ["light.kitchen"])
            #expect(config.items.first?.type == .entity)
            #expect(config.lastModified != nil)
        }
    }

    /// Watch configs predate the static id, so a row written back then has to be replaced rather than
    /// joined by a second one.
    @Test("Adding to the watch replaces a legacy config rather than leaving two rows")
    func addsToWatchReplacingLegacyConfig() throws {
        try withConfigDatabase {
            var legacy = WatchConfig(id: "a-legacy-uuid")
            legacy.items = [MagicItem(id: "light.hall", serverId: "1", type: .entity)]
            try Current.database().write { db in
                try legacy.insert(db, onConflict: .replace)
            }

            _ = try EntityAddToConfigWriter.add(entityId: "light.kitchen", serverId: "1", to: .appleWatch)

            let all = try Current.database().read { db in try WatchConfig.fetchAll(db) }
            #expect(all.count == 1)
            #expect(all.first?.id == WatchConfig.watchConfigId)
            #expect(all.first?.items.map(\.id) == ["light.hall", "light.kitchen"])
        }
    }

    @Test("Adding to CarPlay stores the entity in quick access")
    func addsToCarPlay() throws {
        try withConfigDatabase {
            let outcome = try EntityAddToConfigWriter.add(
                entityId: "light.kitchen",
                serverId: "1",
                to: .carPlay
            )

            #expect(outcome == .added)
            let quickAccess = try #require(CarPlayConfig.config()?.quickAccessItems)
            #expect(quickAccess.map(\.id) == ["light.kitchen"])
        }
    }

    /// The Mac toolbar item carries the icon and name the toolbar draws, and opens the more info
    /// dialog — the same item the frontend's "Add to" sheet writes.
    @Test("Adding to the Mac toolbar stores a more-info item")
    func addsToMacToolbar() throws {
        try withConfigDatabase {
            let outcome = try EntityAddToConfigWriter.add(
                entityId: "light.kitchen",
                serverId: "1",
                to: .macToolbar
            )

            #expect(outcome == .added)
            let item = try #require(MacToolbarConfig.config()?.items.first)
            #expect(item.id == "light.kitchen")
            #expect(item.action == .moreInfoDialog)
            #expect(item.customization?.icon != nil)
        }
    }

    @Test("An entity already at the destination is reported rather than added twice")
    func doesNotAddTwice() throws {
        try withConfigDatabase {
            _ = try EntityAddToConfigWriter.add(entityId: "light.kitchen", serverId: "1", to: .appleWatch)
            let outcome = try EntityAddToConfigWriter.add(
                entityId: "light.kitchen",
                serverId: "1",
                to: .appleWatch
            )

            #expect(outcome == .alreadyPresent)
            let items = try #require(WatchConfig.config()?.items)
            #expect(items.count == 1)
        }
    }

    /// Two servers may each have a `light.kitchen`, and both belong at the destination.
    @Test("The same entity id on another server is a separate item")
    func addsSameEntityIdFromAnotherServer() throws {
        try withConfigDatabase {
            _ = try EntityAddToConfigWriter.add(entityId: "light.kitchen", serverId: "1", to: .appleWatch)
            let outcome = try EntityAddToConfigWriter.add(
                entityId: "light.kitchen",
                serverId: "2",
                to: .appleWatch
            )

            #expect(outcome == .added)
            let items = try #require(WatchConfig.config()?.items)
            #expect(items.map(\.serverId) == ["1", "2"])
        }
    }

    private func withConfigDatabase(perform work: () throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")

        try WatchConfigTable().createIfNeeded(database: database)
        try CarPlayConfigTable().createIfNeeded(database: database)
        try MacToolbarConfigTable().createIfNeeded(database: database)
        try HAppEntityTable().createIfNeeded(database: database)
        Current.database = { database }

        defer { Current.database = previousDatabase }

        try work()
    }
}
