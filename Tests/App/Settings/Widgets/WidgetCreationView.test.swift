import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// The custom widget builder: its preview grows with the items, an item opens its editor whose save
/// writes back, the add rows raise the item picker, and Save stores the widget and closes.
/// Shared state: swaps `Current.database` and `Current.magicItemProvider`; saving reloads widgets.
@MainActor
@Suite(.sharedState)
struct WidgetCreationViewTests {
    private static func items(_ count: Int) -> [MagicItem] {
        (0 ..< count).map { MagicItem(id: "light.light_\($0)", serverId: "1", type: .entity) }
    }

    @Test(arguments: [0, 5, 7])
    func previewSizesFollowTheItemCount(count: Int) async throws {
        try await withWorld { _ in
            let driver = await SwiftUIScreenDriver.show(
                WidgetCreationView(
                    needsNavigationStack: true,
                    widget: CustomWidget(id: "w", name: "Kitchen", items: Self.items(count))
                ) {},
                inNavigationStack: false
            )
            defer { driver.close() }
            // Preview, name, items (+ "Add"), documentation.
            #expect(driver.rowCount(inSection: 2) == count + 1)
            if count == 0 {
                // The empty preview is itself an "add" button.
                await driver.tapRow(IndexPath(item: 0, section: 0))
                await driver.dismissPresented()
            }
        }
    }

    @Test func editingAnItemAndSavingTheWidget() async throws {
        try await withWorld { database in
            var dismissed = 0
            let driver = await SwiftUIScreenDriver.show(WidgetCreationView(
                widget: CustomWidget(id: "w", name: "", items: Self.items(1))
            ) { dismissed += 1 })
            defer { driver.close() }

            try await #require(driver.push(IndexPath(item: 0, section: 2)))
            await driver.tapBarButton(titled: L10n.MagicItem.edit)
            await driver.popToRoot()

            await driver.tapRow(IndexPath(item: 1, section: 2))
            await driver.dismissPresented()

            await driver.type("Kitchen")
            let pressed = await driver.tapBarButton(titled: L10n.saveLabel)
            #expect(pressed)
            await #expect(driver.waitUntil { dismissed == 1 })
            let stored = try await database.read { db in try CustomWidget.fetchAll(db) }
            #expect(stored.map(\.name) == ["Kitchen"])
        }
    }

    private func withWorld(_ body: (DatabaseQueue) async throws -> Void) async throws {
        let previousProvider = Current.magicItemProvider
        defer { Current.magicItemProvider = previousProvider }
        Current.magicItemProvider = { NamedItemProvider() }
        try await SettingsTestDatabase.with { database in
            try await body(database)
        }
    }
}

private final class NamedItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(id: item.serverUniqueId, name: "Light", iconName: "mdi:lightbulb")
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
