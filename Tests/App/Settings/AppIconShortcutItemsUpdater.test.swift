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
            requiringAssertion: Bool,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            wrapping(nil)
        }
    }

    private final class StubMagicItemProvider: MagicItemProviderProtocol {
        /// What the entity read produced per server; a server missing from it is one whose read failed.
        let entitiesPerServer: [String: [HAAppEntity]]

        init(entitiesPerServer: [String: [HAAppEntity]]) {
            self.entitiesPerServer = entitiesPerServer
        }

        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion(entitiesPerServer)
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            entitiesPerServer
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            .init(id: item.serverUniqueId, name: "Kitchen light", iconName: "mdi:lightbulb", contextSubtitle: nil)
        }

        func getAreaName(for item: MagicItem) -> String? {
            "Kitchen"
        }
    }

    private final class HeldMagicItemProvider: MagicItemProviderProtocol, @unchecked Sendable {
        private let lock = NSLock()
        private let gate = DispatchSemaphore(value: 0)
        private var didStart = false

        var hasStarted: Bool {
            lock.lock()
            defer { lock.unlock() }
            return didStart
        }

        func release() {
            gate.signal()
        }

        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            lock.lock()
            didStart = true
            lock.unlock()
            gate.wait()
            completion([AppIconShortcutItemsUpdaterTests.serverId: []])
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            [AppIconShortcutItemsUpdaterTests.serverId: []]
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            .init(id: item.serverUniqueId, name: "Stale light", iconName: "mdi:lightbulb", contextSubtitle: nil)
        }

        func getAreaName(for item: MagicItem) -> String? {
            nil
        }
    }

    /// `update()` publishes onto the main queue from a private work queue, so assertions wait for
    /// it. `await` rather than a blocking poll: these tests run on the main actor, and blocking it
    /// would starve the very `DispatchQueue.main.async` they are waiting on.
    @MainActor
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

    private static let serverId = "1"

    /// Configures `items`, registers server `"1"` and stubs an entity read that succeeded for it
    /// with no rows — enough for the provider stub to resolve every item.
    /// Kept non-async for the same reason as `makeDatabase`.
    private func save(items: [MagicItem], to database: DatabaseQueue) throws {
        try database.write { db in
            try AppIconShortcutConfig(items: items).save(db)
        }
    }

    @MainActor
    private func withConfiguredItems(
        _ items: [MagicItem],
        entitiesPerServer: [String: [HAAppEntity]] = [serverId: []],
        _ body: @MainActor (DatabaseQueue) async throws -> Void
    ) async throws {
        let database = try makeDatabase(items: items)
        let servers = FakeServerManager()
        servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())

        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        let previousRunner = Current.backgroundTask
        let previousServers = Current.servers
        Current.database = { database }
        Current.magicItemProvider = { StubMagicItemProvider(entitiesPerServer: entitiesPerServer) }
        Current.backgroundTask = PassthroughBackgroundTaskRunner()
        Current.servers = servers
        defer {
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
            Current.backgroundTask = previousRunner
            Current.servers = previousServers
            UIApplication.shared.shortcutItems = []
        }

        try await body(database)
    }

    @MainActor
    private func update() async {
        await withCheckedContinuation { continuation in
            AppIconShortcutItemsUpdater.update { continuation.resume() }
        }
    }

    @MainActor
    private var publishedTypes: [String] {
        UIApplication.shared.shortcutItems?.map(\.type) ?? []
    }

    private func entityItem(id: String, serverId: String = serverId) -> MagicItem {
        MagicItem(id: id, serverId: serverId, type: .entity)
    }

    @MainActor
    @Test("Publishes a shortcut item for each configured item")
    func publishesConfiguredItems() async throws {
        try await withConfiguredItems([entityItem(id: "light.kitchen"), entityItem(id: "light.hall")]) { _ in
            await update()

            #expect(publishedTypes == [
                "appIconShortcut.1|entity|light.kitchen",
                "appIconShortcut.1|entity|light.hall",
            ])
        }
    }

    @MainActor
    @Test("Resolves the item's name and area through the provider")
    func resolvesNameAndArea() async throws {
        try await withConfiguredItems([entityItem(id: "light.kitchen")]) { _ in
            await update()

            let item = UIApplication.shared.shortcutItems?.first
            #expect(item?.localizedTitle == "Kitchen light")
            #expect(item?.localizedSubtitle == "Kitchen")
        }
    }

    @MainActor
    @Test("Publishes at most four items")
    func publishesAtMostFourItems() async throws {
        let items = (0 ..< 6).map { entityItem(id: "light.number\($0)") }
        try await withConfiguredItems(items) { _ in
            await update()

            #expect(publishedTypes == (0 ..< 4).map { "appIconShortcut.1|entity|light.number\($0)" })
        }
    }

    @MainActor
    @Test("Publishes nothing when no items are configured")
    func publishesNothingWhenUnconfigured() async throws {
        try await withConfiguredItems([]) { _ in
            await update()

            #expect(publishedTypes.isEmpty)
        }
    }

    @MainActor
    @Test("Keeps the published items when a configured server's entities could not be read")
    func keepsPublishedItemsWhenEntitiesCannotBeRead() async throws {
        try await withConfiguredItems([entityItem(id: "light.kitchen")]) { _ in
            await update()
            #expect(publishedTypes == ["appIconShortcut.1|entity|light.kitchen"])

            Current.magicItemProvider = { StubMagicItemProvider(entitiesPerServer: [:]) }
            await update()

            #expect(publishedTypes == ["appIconShortcut.1|entity|light.kitchen"])
            #expect(UIApplication.shared.shortcutItems?.first?.localizedTitle == "Kitchen light")
        }
    }

    @MainActor
    @Test("Still publishes when the unread server is no longer configured")
    func publishesWhenUnreadServerIsGone() async throws {
        let items = [entityItem(id: "light.kitchen", serverId: "gone")]
        try await withConfiguredItems(items, entitiesPerServer: [:]) { _ in
            await update()

            #expect(publishedTypes == ["appIconShortcut.gone|entity|light.kitchen"])
        }
    }

    @MainActor
    @Test("An update that finishes after a newer one does not replace it")
    func olderUpdateDoesNotReplaceNewerOne() async throws {
        try await withConfiguredItems([entityItem(id: "light.kitchen")]) { _ in
            let heldProvider = HeldMagicItemProvider()
            Current.magicItemProvider = { heldProvider }
            let olderUpdate = Task { await update() }
            let started = await waitUntil { heldProvider.hasStarted }
            #expect(started)

            Current.magicItemProvider = { StubMagicItemProvider(entitiesPerServer: [Self.serverId: []]) }
            await update()
            heldProvider.release()
            await olderUpdate.value

            #expect(UIApplication.shared.shortcutItems?.map(\.localizedTitle) == ["Kitchen light"])
        }
    }

    @MainActor
    @Test("Republishes when the database updater finishes a server")
    func republishesWhenDatabaseUpdaterFinishes() async throws {
        try await withConfiguredItems([entityItem(id: "light.kitchen")]) { database in
            defer { AppIconShortcutItemsUpdater.stop() }
            AppIconShortcutItemsUpdater.start()
            let published = await waitUntil { publishedTypes == ["appIconShortcut.1|entity|light.kitchen"] }
            #expect(published)

            try save(items: [entityItem(id: "light.kitchen"), entityItem(id: "light.hall")], to: database)
            NotificationCenter.default.post(name: .appDatabaseUpdaterDidFinishRoutine, object: nil)

            let republished = await waitUntil {
                publishedTypes == ["appIconShortcut.1|entity|light.kitchen", "appIconShortcut.1|entity|light.hall"]
            }
            #expect(republished)
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
