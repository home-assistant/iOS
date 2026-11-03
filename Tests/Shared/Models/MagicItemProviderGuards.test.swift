import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// The edges of `MagicItemProvider`: migrations that must not run from an extension, configs that
/// can't be loaded or saved, and the info and area names of items it has no entity for.
///
/// `.isolatedEnvironment`: the configs, database, servers and `isAppExtension` are read on the
/// test's own task.
@Suite(.isolatedEnvironment)
struct MagicItemProviderGuardsTests {
    /// An extension never rewrites the app's configs; every migration just completes.
    @Test func extensionsSkipEveryMigration() async {
        Current.isAppExtension = true
        Current.carPlayConfig = { Issue.record("read from an extension"); return nil }
        let provider = MagicItemProvider()
        await migrate(provider)
    }

    /// Configs that don't exist yet leave nothing to migrate.
    @Test func missingConfigsLeaveNothingToMigrate() async {
        Current.isAppExtension = false
        Current.carPlayConfig = { nil }
        Current.watchConfig = { nil }
        Current.appIconShortcutConfig = { nil }
        Current.customWidgets = { throw Unreadable() }
        await migrate(MagicItemProvider())
    }

    /// A database that refuses the write leaves the stored configs as they were and still
    /// completes, so a failed migration never blocks loading.
    @Test func aFailedSaveStillCompletes() async throws {
        Current.isAppExtension = false
        let database = try DatabaseQueue()
        Current.database = { database }
        let item = MagicItem(id: "light.a", serverId: "s", type: .entity)
        Current.carPlayConfig = { CarPlayConfig(quickAccessItems: [item], tabFolders: [item]) }
        Current.watchConfig = { WatchConfig(items: [item]) }
        Current.appIconShortcutConfig = { AppIconShortcutConfig(items: [item]) }
        Current.customWidgets = { [CustomWidget(id: "w", name: "W", items: [item])] }
        await migrate(MagicItemProvider())
    }

    @Test func itemsWithoutEntitiesDescribeThemselves() {
        let servers = FakeServerManager()
        _ = servers.add(identifier: .init(rawValue: "one"), serverInfo: .fake())
        _ = servers.add(identifier: .init(rawValue: "two"), serverInfo: .fake())
        Current.servers = servers
        let provider = MagicItemProvider()
        provider.entitiesPerServer = ["one": []]

        let preferred = provider.getInfo(for: MagicItem(
            id: "",
            serverId: "one",
            type: .assistPipeline,
            assistPipelineId: ""
        ))
        #expect(preferred?.name == L10n.AppIntents.Assist.PreferredPipeline.title)
        #expect(provider.getInfo(for: MagicItem(id: "x", serverId: "one", type: .unsupported)) == nil)
        #expect(provider.getAreaName(for: MagicItem(id: "light.a", serverId: "one", type: .entity)) == nil)
        #expect(provider.getAreaName(for: MagicItem(id: "light.a", serverId: "gone", type: .entity)) == nil)
        _ = provider.getInfo(for: MagicItem(id: "kitchen", serverId: "two", type: .area))
    }

    // MARK: - Helpers

    private struct Unreadable: Error {}

    private func migrate(_ provider: MagicItemProvider) async {
        await withCheckedContinuation { continuation in provider.migrateCarPlayConfig { continuation.resume() } }
        await withCheckedContinuation { continuation in provider.migrateWatchConfig { continuation.resume() } }
        await withCheckedContinuation { continuation in
            provider.migrateAppIconShortcutConfig { continuation.resume() }
        }
        await withCheckedContinuation { continuation in provider.migrateWidgetsConfig { continuation.resume() } }
    }
}
