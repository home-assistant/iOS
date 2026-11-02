import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays the Mac toolbar settings out with no items and with items from two servers, and removes an
/// item through its view model.
///
/// `.sharedState`: the test swaps `Current.database` and `Current.servers`.
@Suite(.sharedState)
@MainActor
struct MacToolbarSettingsViewTests {
    private func withServers(_ count: Int, _ body: ([Server]) async throws -> Void) async throws {
        let previous = Current.servers
        let manager = FakeServerManager(initial: count)
        Current.servers = manager
        defer { Current.servers = previous }
        try await body(manager.all)
    }

    private static func items(serverId: String) -> [MagicItem] {
        var named = MagicItem(id: "script.open_gate", serverId: serverId, type: .script)
        named.displayText = "Open gate"
        var iconed = MagicItem(
            id: "light.kitchen",
            serverId: serverId,
            type: .entity,
            customization: .init(icon: "lightbulb")
        )
        iconed.displayText = nil
        return [named, iconed]
    }

    @Test func showsTheEmptyState() async throws {
        try await withServers(1) { _ in
            try await SettingsTestDatabase.with { _ in
                let harness = await SettingsScreenHarness.show(MacToolbarSettingsView())
                #expect(harness.rows.filter { $0.section == 2 }.count == 1)
                await harness.close()
            }
        }
    }

    @Test func listsItemsWithTheirServerAndRemovesOne() async throws {
        try await withServers(2) { servers in
            let items = Self.items(serverId: servers[1].identifier.rawValue)
            try await SettingsTestDatabase.with({ db in
                try MacToolbarConfig(items: items).insert(db)
            }) { database in
                let harness = await SettingsScreenHarness.show(MacToolbarSettingsView())
                await #expect(harness.waitUntil { harness.rows.filter { $0.section == 2 }.count == 2 })
                await harness.close()

                let viewModel = MacToolbarSettingsViewModel()
                viewModel.load()
                #expect(viewModel.items.count == 2)
                viewModel.remove(items[0])
                #expect(viewModel.items.map(\.id) == ["light.kitchen"])
                let stored = try await database.read { db in try MacToolbarConfig.fetchOne(db)?.items.map(\.id) }
                #expect(stored == ["light.kitchen"])
            }
        }
    }

    @Test func removingWithoutAConfigCreatesOne() async throws {
        try await withServers(1) { servers in
            try await SettingsTestDatabase.with { database in
                let viewModel = MacToolbarSettingsViewModel()
                viewModel.load()
                #expect(viewModel.items.isEmpty)
                viewModel.remove(MagicItem(id: "x", serverId: servers[0].identifier.rawValue, type: .script))
                let stored = try await database.read { db in try MacToolbarConfig.fetchCount(db) }
                #expect(stored == 1)
            }
        }
    }

    /// Without the toolbar table, loading falls back to no items and removing leaves them alone.
    @Test func aDatabaseWithoutItsTableLoadsNothingAndKeepsItems() async throws {
        let items = Self.items(serverId: "server")
        let viewModel = MacToolbarSettingsViewModel()
        try await SettingsTestDatabase.with({ db in try MacToolbarConfig(items: items).insert(db) }) { _ in
            viewModel.load()
        }
        #expect(viewModel.items.count == 2)

        try await SettingsTestDatabase.withoutTables { _ in
            viewModel.remove(items[0])
            #expect(viewModel.items.count == 2)
            viewModel.load()
            #expect(viewModel.items.isEmpty)
        }
    }
}
