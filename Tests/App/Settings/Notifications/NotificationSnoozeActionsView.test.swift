import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Shared state: the snooze actions live in `Current.database`, read from the main run loop.
@Suite(.sharedState)
@MainActor
struct NotificationSnoozeActionsViewTests {
    @Test func viewModelAddsTogglesMovesAndDeletes() throws {
        try withDatabase {
            let viewModel = NotificationSnoozeActionsViewModel()
            viewModel.load()
            // A new database is seeded with the defaults.
            #expect(viewModel.actions.map(\.minutes) == [5, 15, 60])

            viewModel.add(minutes: 30)
            viewModel.add(minutes: 15)
            #expect(viewModel.actions.map(\.minutes) == [5, 15, 60, 30])

            viewModel.setEnabled(false, for: viewModel.actions[0])
            #expect(!viewModel.actions[0].isEnabled)

            viewModel.move(from: IndexSet(integer: 3), to: 0)
            #expect(viewModel.actions.map(\.minutes) == [30, 5, 15, 60])

            viewModel.delete(at: IndexSet(integer: 0))
            #expect(viewModel.actions.map(\.minutes) == [5, 15, 60])
        }
    }

    @Test func titlesSpellOutHoursAndMinutes() {
        for minutes in [10, 60, 120, 65, 125] {
            #expect(!NotificationSnoozeAction(minutes: minutes, sortOrder: 0).title.isEmpty)
        }
    }

    /// The add sheet walks its duration through every label (minutes, an hour, hours, an hour and
    /// minutes, hours and minutes), warns about a duplicate, then adds a new duration.
    @Test func addSheetAddsANewDuration() async throws {
        try await withDatabase {
            let driver = await SwiftUIScreenDriver.show(NotificationSnoozeActionsView())
            defer { driver.close() }
            // The seeded defaults, then "Add".
            #expect(driver.rowCount(inSection: 0) == 4)

            await driver.toggleSwitches()
            await #expect(driver.waitUntil { NotificationSnoozeAction.all().allSatisfy { !$0.isEnabled } })

            await driver.tapRow(IndexPath(item: 3, section: 0))
            await #expect(driver.waitUntil { driver.presented != nil })
            // 10 → 60 (already there: a duplicate) → 65 → 120 → 125 minutes.
            await driver.step(10)
            await driver.step(1)
            await driver.step(11)
            await driver.step(1)
            await #expect(driver.tapBarButton(titled: L10n.addButtonLabel))
            await #expect(driver.waitUntil { NotificationSnoozeAction.all().map(\.minutes) == [5, 15, 60, 125] })
            await driver.dismissPresented()
            await #expect(driver.waitUntil { driver.rowCount(inSection: 0) == 5 })
        }
    }

    private func withDatabase(_ body: () async throws -> Void) async throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previous = Current.database
        Current.database = { database }
        defer { Current.database = previous }
        try await body()
    }

    private func withDatabase(_ body: () throws -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previous = Current.database
        Current.database = { database }
        defer { Current.database = previous }
        try body()
    }
}
