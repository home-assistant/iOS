import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Building a custom widget: its items are added, edited, reordered and removed, and Save refuses a
/// widget without a name or items, stores a complete one, and reports a database failure.
/// Shared state: swaps `Current.database` and `Current.magicItemProvider`; saving reloads widgets.
@Suite(.sharedState)
struct WidgetCreationViewModelTests {
    private let kitchen = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
    private let porch = MagicItem(id: "light.porch", serverId: "1", type: .entity)
    private let pump = MagicItem(id: "switch.pump", serverId: "1", type: .entity)

    @Test func itemsAreAddedEditedMovedAndRemoved() {
        let viewModel = WidgetCreationViewModel(widget: CustomWidget(id: "w", name: "Widget", items: []))
        viewModel.addItem(kitchen)
        viewModel.addItem(porch)
        viewModel.addItem(pump)

        var renamed = porch
        renamed.displayText = "Porch"
        viewModel.updateItem(renamed)
        #expect(viewModel.widget.items[1].displayText == "Porch")
        viewModel.updateItem(MagicItem(id: "unknown", serverId: "1", type: .entity))
        #expect(viewModel.widget.items.count == 3)

        viewModel.moveItem(from: IndexSet(integer: 0), to: 3)
        #expect(viewModel.widget.items.map(\.id) == ["light.porch", "switch.pump", "light.kitchen"])
        viewModel.deleteItem(at: IndexSet(integer: 0))
        viewModel.deleteItem(pump)
        viewModel.deleteItem(MagicItem(id: "unknown", serverId: "1", type: .entity))
        #expect(viewModel.widget.items.map(\.id) == ["light.kitchen"])
    }

    @Test func saveNeedsANameAndItemsThenStoresTheWidget() throws {
        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        defer {
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
        }
        let database = try SettingsTestDatabase.make()
        Current.database = { database }
        Current.magicItemProvider = { SilentMagicItemProvider() }

        let viewModel = WidgetCreationViewModel(widget: CustomWidget(id: "w", name: "  ", items: [kitchen]))
        viewModel.load()
        viewModel.save()
        #expect(viewModel.showError)
        #expect(!viewModel.shouldDismiss)

        viewModel.showError = false
        viewModel.widget.name = "Kitchen"
        viewModel.save()
        #expect(viewModel.shouldDismiss)
        let stored = try database.read { db in try CustomWidget.fetchAll(db) }
        #expect(stored.map(\.name) == ["Kitchen"])

        Current.database = { try! DatabaseQueue() }
        viewModel.shouldDismiss = false
        viewModel.save()
        #expect(viewModel.showError)
        #expect(!viewModel.shouldDismiss)
    }
}

private final class SilentMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        nil
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
