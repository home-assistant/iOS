import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// The app icon quick actions editor and its view model: loading the stored items, adding (without
/// duplicates), editing, reordering and removing them with every change saved, resetting, and
/// reporting database failures.
/// Shared state: swaps `Current.database` and `Current.magicItemProvider`, and saving refreshes the
/// host app's quick actions.
@MainActor
@Suite(.sharedState)
struct AppIconShortcutsConfigurationTests {
    private let kitchen = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
    private let porch = MagicItem(id: "light.porch", serverId: "1", type: .entity)

    @Test func itemsAreEditedAndEveryChangeIsSaved() async throws {
        try await withWorld { database, updates in
            let viewModel = AppIconShortcutsConfigurationViewModel(updateShortcutItems: updates.start)
            viewModel.loadConfig()
            #expect(viewModel.config.items.isEmpty)
            #expect(viewModel.magicItemInfo(for: kitchen)?.name == "Kitchen light")

            viewModel.addItem(kitchen)
            viewModel.addItem(porch)
            viewModel.addItem(kitchen)
            await waitUntil { viewModel.showError }
            #expect(viewModel.errorMessage == L10n.Settings.AppIconShortcuts.duplicateError)
            #expect(viewModel.config.items.count == 2)

            var renamed = kitchen
            renamed.displayText = "Kitchen"
            viewModel.updateItem(renamed)
            #expect(viewModel.config.items.first?.displayText == "Kitchen")

            viewModel.moveItem(from: IndexSet(integer: 0), to: 2)
            #expect(viewModel.config.items.map(\.id) == ["light.porch", "light.kitchen"])
            viewModel.deleteItem(at: IndexSet(integer: 0))
            #expect(viewModel.config.items.map(\.id) == ["light.kitchen"])

            await waitUntil { (try? AppIconShortcutConfig.config())?.items.map(\.id) == ["light.kitchen"] }
            let stored = try AppIconShortcutConfig.config()
            #expect(stored?.items.map(\.id) == ["light.kitchen"])

            var reset: Bool?
            viewModel.deleteConfiguration { reset = $0 }
            #expect(reset == true)
            let count = try await database.read { db in try AppIconShortcutConfig.fetchCount(db) }
            #expect(count == 0)
        }
    }

    /// A configuration already stored is loaded as is.
    @Test func aStoredConfigurationIsLoaded() async throws {
        try await withWorld { database, updates in
            try await database.write { db in
                try AppIconShortcutConfig(items: [porch]).insert(db, onConflict: .replace)
            }
            let viewModel = AppIconShortcutsConfigurationViewModel(updateShortcutItems: updates.start)
            viewModel.loadConfig()
            #expect(viewModel.config.items.map(\.id) == ["light.porch"])
        }
    }

    @Test func databaseFailuresAreReported() async throws {
        try await withWorld { _, updates in
            let viewModel = AppIconShortcutsConfigurationViewModel(updateShortcutItems: updates.start)
            viewModel.loadConfig()

            // Without the table, saving the next change fails.
            Current.database = { try! DatabaseQueue() }
            viewModel.addItem(kitchen)
            await waitUntil { viewModel.showError }
            #expect(viewModel.showError)

            var reset: Bool?
            viewModel.deleteConfiguration { reset = $0 }
            #expect(reset == false)

            let unreadable = AppIconShortcutsConfigurationViewModel(updateShortcutItems: updates.start)
            unreadable.loadConfig()
            await waitUntil { unreadable.showError }
            #expect(unreadable.showError)
        }
    }

    /// The screen loads the stored items when it appears; an item opens its editor, whose save
    /// writes the edit back, and "Add" and "Reset" only raise their sheet and confirmation.
    @Test func theScreenLoadsAndEditsItsItems() async throws {
        try await withWorld { database, updates in
            try await database.write { db in
                try AppIconShortcutConfig(items: [kitchen]).insert(db, onConflict: .replace)
            }
            let viewModel = AppIconShortcutsConfigurationViewModel(updateShortcutItems: updates.start)
            let driver = await SwiftUIScreenDriver.show(AppIconShortcutsConfigurationView(viewModel: viewModel))
            defer { driver.close() }
            await #expect(driver.waitUntil { viewModel.config.items.count == 1 })

            // Header, then the items followed by "Add", then reset.
            try await #require(driver.push(IndexPath(item: 0, section: 1)))
            await driver.type("Kitchen")
            await driver.tapBarButton(titled: L10n.MagicItem.edit)
            await driver.popToRoot()
            await #expect(driver.waitUntil { viewModel.config.items.first?.displayText == "Kitchen" })

            await driver.tapRow(IndexPath(item: 1, section: 1))
            #expect(viewModel.showAddItem)
            await driver.dismissPresented()
            await driver.tapRow(IndexPath(item: 0, section: 2))
            await driver.dismissPresented()
            #expect(viewModel.config.items.count == 1)
        }
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 500 where !condition() {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// Runs `body` against a test database and item provider. Every quick-action refresh the view models
    /// start reads both later, off the main thread, and then publishes to the host app's shortcut items:
    /// they are all awaited before the environment is restored, and the app's shortcut items put back.
    private func withWorld(_ body: (DatabaseQueue, ShortcutUpdates) async throws -> Void) async throws {
        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        let previousShortcutItems = UIApplication.shared.shortcutItems
        let updates = ShortcutUpdates()
        let database = try SettingsTestDatabase.make()
        Current.database = { database }
        Current.magicItemProvider = { NamedMagicItemProvider() }

        var failure: Error?
        do {
            try await body(database, updates)
        } catch {
            failure = error
        }

        // Saves run in main-actor tasks the view model queued; let them start their refreshes first.
        for _ in 0 ..< 5 {
            await Task.yield()
        }
        let deadline = Date().addingTimeInterval(10)
        while !updates.allFinished, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(updates.allFinished, "quick-action refreshes still running")

        Current.database = previousDatabase
        Current.magicItemProvider = previousProvider
        UIApplication.shared.shortcutItems = previousShortcutItems
        if let failure {
            throw failure
        }
    }
}

/// Starts the real quick-action refresh for the view model and counts the ones still running.
private final class ShortcutUpdates: @unchecked Sendable {
    private let lock = NSLock()
    private var running = 0

    var allFinished: Bool {
        lock.withLock { running == 0 }
    }

    func start() {
        lock.withLock { running += 1 }
        AppIconShortcutItemsUpdater.update { [self] in
            lock.withLock { running -= 1 }
        }
    }
}

private final class NamedMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(id: item.serverUniqueId, name: "Kitchen light", iconName: "mdi:lightbulb")
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
