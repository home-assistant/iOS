import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lists custom widgets from an in-memory database, opens one, reloads them all and deletes them
/// through the screen and through its view model.
///
/// `.sharedState`: the test swaps `Current.database`.
@Suite(.sharedState)
@MainActor
struct CustomWidgetsListViewTests {
    private static func seed(_ db: Database) throws {
        try CustomWidget(id: "b", name: "Bedroom", items: []).insert(db)
        try CustomWidget(
            id: "a",
            name: "Alarm",
            items: [.init(id: "script.alarm", serverId: "server", type: .script)]
        ).insert(db)
        try CustomWidget(id: "c", name: "Cameras", items: []).insert(db)
    }

    @Test func viewModelLoadsSortedAndDeletes() async throws {
        try await SettingsTestDatabase.with(Self.seed) { _ in
            let viewModel = WidgetBuilderViewModel()
            viewModel.loadWidgets()
            #expect(viewModel.widgets.map(\.name) == ["Alarm", "Bedroom", "Cameras"])

            viewModel.deleteItem(at: IndexSet(integer: 0))
            #expect(viewModel.widgets.map(\.name) == ["Bedroom", "Cameras"])

            viewModel.deleteWidget(viewModel.widgets[0])
            #expect(viewModel.widgets.map(\.name) == ["Cameras"])

            viewModel.deleteAllWidgets()
            #expect(viewModel.widgets.isEmpty)

            viewModel.reloadWidgets()
            #expect(viewModel.isLoading)
        }
    }

    @Test func listsOpensAndReloadsWidgets() async throws {
        try await SettingsTestDatabase.with(Self.seed) { _ in
            let harness = await SettingsScreenHarness.show(CustomWidgetsListView())
            await #expect(harness.waitUntil { harness.rows.count >= 8 })

            // Open each widget and the "create" row, coming back each time.
            var opened = 0
            for row in harness.rows where row.section == 1 {
                if await harness.push(row) {
                    opened += 1
                    await harness.pop()
                }
            }
            #expect(opened == 4)
            // The reload row runs its button.
            await harness.tapRow(IndexPath(item: 0, section: 2))
            await harness.close()
        }
    }

    @Test func deleteAllAsksForConfirmationFirst() async throws {
        try await SettingsTestDatabase.with(Self.seed) { database in
            let harness = await SettingsScreenHarness.show(CustomWidgetsListView())
            await #expect(harness.waitUntil { harness.rows.count >= 8 })

            await harness.tapRow(IndexPath(item: 0, section: 3))
            await #expect(harness.waitUntil(timeout: 5) { harness.alert != nil })
            await harness.tapAlertButton(L10n.yesLabel)
            let remaining = try await database.read { db in try CustomWidget.fetchCount(db) }
            #expect(remaining == 0)
            await harness.close()
        }
    }

    /// Saving a widget opened from the list pops back to the list, which reloads its widgets.
    @Test func savingAnOpenedWidgetReturnsToTheReloadedList() async throws {
        try await SettingsTestDatabase.with(Self.seed) { _ in
            let driver = await SwiftUIScreenDriver.show(CustomWidgetsListView())
            defer { driver.close() }
            await #expect(driver.waitUntil { driver.rowCount(inSection: 1) == 4 })

            // "Alarm" sorts first and is the only seeded widget with an item, so it can be saved.
            try await #require(driver.push(IndexPath(item: 0, section: 1)))
            let saved = await driver.tapBarButton(titled: L10n.saveLabel)
            #expect(saved)
            await #expect(driver.waitUntil { driver.depth == 1 })
            #expect(driver.rowCount(inSection: 1) == 4)
        }
    }

    /// Without its table every database call fails; the view model logs it and keeps what it has.
    @Test func viewModelSurvivesADatabaseWithoutItsTable() async throws {
        let viewModel = WidgetBuilderViewModel()
        try await SettingsTestDatabase.with(Self.seed) { _ in
            viewModel.loadWidgets()
        }
        #expect(viewModel.widgets.count == 3)

        try await SettingsTestDatabase.withoutTables { _ in
            viewModel.loadWidgets()
            #expect(viewModel.widgets.count == 3)
            viewModel.deleteItem(at: IndexSet(integer: 0))
            viewModel.deleteWidget(viewModel.widgets[0])
            viewModel.deleteAllWidgets()
            #expect(viewModel.widgets.count == 3)
        }
    }

    @Test func showsTheEmptyList() async throws {
        try await SettingsTestDatabase.with { _ in
            let harness = await SettingsScreenHarness.show(CustomWidgetsListView())
            #expect(harness.rows.count >= 4)
            await harness.close()
        }
    }
}
