import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lists the rectangular complications a watch list can hold, adds one with a tap, and shows the
/// empty state when the database cannot be read.
///
/// `.sharedState`: the test swaps `Current.database` and `Current.servers`.
@Suite(.sharedState)
@MainActor
struct ComplicationMagicItemAddListTests {
    private final class Added {
        var items: [MagicItem] = []
    }

    @Test func tappingAComplicationAddsIt() async throws {
        let previousServers = Current.servers
        let servers = FakeServerManager(initial: 1)
        Current.servers = servers
        defer { Current.servers = previousServers }
        let serverId = servers.all[0].identifier.rawValue

        try await SettingsTestDatabase.with({ db in
            try WatchComplicationConfig(
                id: "battery",
                serverId: serverId,
                widgetFamily: .rectangular,
                name: "Battery",
                entityId: "sensor.battery",
                iconName: "battery",
                iconColor: "#FF0000"
            ).insert(db)
            try WatchComplicationConfig(id: "round", serverId: serverId, widgetFamily: .circular, name: "Round")
                .insert(db)
        }) { _ in
            let added = Added()
            let driver = await SwiftUIScreenDriver.show(ComplicationMagicItemAddList { added.items.append($0) })
            defer { driver.close() }

            await #expect(driver.waitUntil { driver.rows.count == 1 })
            await driver.tapRow(IndexPath(item: 0, section: 0))
            #expect(added.items.map(\.id) == ["battery"])
            #expect(added.items.first?.type == .complication)
        }
    }

    @Test func aDatabaseWithoutTablesShowsTheEmptyState() async throws {
        try await SettingsTestDatabase.withoutTables { _ in
            let driver = await SwiftUIScreenDriver.show(ComplicationMagicItemAddList { _ in })
            defer { driver.close() }
            #expect(driver.sectionCount == 1)
            #expect(driver.rowCount(inSection: 0) == 1)
        }
    }
}
