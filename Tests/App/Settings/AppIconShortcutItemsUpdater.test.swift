import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing
import UIKit

/// Serialized because every test swaps globals on `Current`.
@Suite("AppIconShortcutItemsUpdater", .serialized)
struct AppIconShortcutItemsUpdaterTests {
    /// Runs the wrapped work without a real `UIApplication`/`ProcessInfo` assertion.
    private final class PassthroughBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
        func callAsFunction<PromiseValue>(
            withName name: String,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            wrapping(nil)
        }
    }

    private final class StubMagicItemProvider: MagicItemProviderProtocol {
        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion([:])
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            [:]
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            .init(id: item.serverUniqueId, name: "Kitchen light", iconName: "mdi:lightbulb", contextSubtitle: nil)
        }

        func getAreaName(for item: MagicItem) -> String? {
            "Kitchen"
        }
    }

    /// `update()` publishes onto the main queue from a private work queue, so assertions wait for
    /// it. `await` rather than a blocking poll: these tests run on the main actor, and blocking it
    /// would starve the very `DispatchQueue.main.async` they are waiting on.
    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 500 {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// Kept non-async so GRDB resolves the synchronous `write` overload.
    private func makeDatabase(items: [MagicItem]) throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            try AppIconShortcutConfig(items: items).save(db)
        }
        return database
    }

    private func withConfiguredItems(_ items: [MagicItem], _ body: () async throws -> Void) async throws {
        let database = try makeDatabase(items: items)

        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        let previousRunner = Current.backgroundTask
        Current.database = { database }
        Current.magicItemProvider = { StubMagicItemProvider() }
        Current.backgroundTask = PassthroughBackgroundTaskRunner()
        defer {
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
            Current.backgroundTask = previousRunner
            DispatchQueue.main.async { UIApplication.shared.shortcutItems = [] }
        }

        try await body()
    }

    private func entityItem(id: String) -> MagicItem {
        MagicItem(id: id, serverId: "1", type: .entity)
    }

    @MainActor
    @Test("Publishes a shortcut item for each configured item")
    func publishesConfiguredItems() async throws {
        try await withConfiguredItems([entityItem(id: "light.kitchen"), entityItem(id: "light.hall")]) {
            AppIconShortcutItemsUpdater.update()

            #expectawait (waitUntil { UIApplication.shared.shortcutItems?.count == 2 })
            let types = UIApplication.shared.shortcutItems?.map(\.type) ?? []
            #expect(types.contains("appIconShortcut.1|entity|light.kitchen"))
            #expect(types.contains("appIconShortcut.1|entity|light.hall"))
        }
    }

    @MainActor
    @Test("Resolves the item's name and area through the provider")
    func resolvesNameAndArea() async throws {
        try await withConfiguredItems([entityItem(id: "light.kitchen")]) {
            AppIconShortcutItemsUpdater.update()

            #expectawait (waitUntil { UIApplication.shared.shortcutItems?.isEmpty == false })
            let item = UIApplication.shared.shortcutItems?.first
            #expect(item?.localizedTitle == "Kitchen light")
            #expect(item?.localizedSubtitle == "Kitchen")
        }
    }

    @MainActor
    @Test("Publishes at most four items")
    func publishesAtMostFourItems() async throws {
        let items = (0 ..< 6).map { entityItem(id: "light.number\($0)") }
        try await withConfiguredItems(items) {
            AppIconShortcutItemsUpdater.update()

            #expectawait (waitUntil { UIApplication.shared.shortcutItems?.count == 4 })
        }
    }

    @MainActor
    @Test("Publishes nothing when no items are configured")
    func publishesNothingWhenUnconfigured() async throws {
        try await withConfiguredItems([]) {
            AppIconShortcutItemsUpdater.update()

            #expectawait (waitUntil { UIApplication.shared.shortcutItems?.isEmpty == true })
        }
    }

    @Test("Round-trips a shortcut type back into its identifier")
    func parsesShortcutType() {
        let identifier = AppIconShortcutItemsUpdater.identifier(from: "appIconShortcut.1|entity|light.kitchen")

        #expect(identifier?.serverId == "1")
        #expect(identifier?.itemId == "light.kitchen")
        #expect(identifier?.itemType == .entity)
    }

    @Test("Ignores a shortcut type that is not ours")
    func ignoresForeignShortcutType() {
        #expect(AppIconShortcutItemsUpdater.identifier(from: "openSettings") == nil)
    }
}
