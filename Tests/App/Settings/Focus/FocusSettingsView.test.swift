import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays the Focus settings screen out with and without names, with the sensor and permission warnings
/// shown or hidden, follows its links and adds a name through its alert.
///
/// `.sharedState`: the test swaps `Current.database`, `Current.focusFilter` and `Current.focusStatus`.
@Suite(.sharedState)
@MainActor
struct FocusSettingsViewTests {
    private func withFocus(
        names: [String],
        active: String?,
        authorized: Bool,
        _ body: (DatabaseQueue) async throws -> Void
    ) async throws {
        let previousFilter = Current.focusFilter
        let previousStatus = Current.focusStatus
        let filter = FocusFilterWrapper()
        filter.activeFocusName = { active }
        filter.forgetFocusName = { _ in }
        let status = FocusStatusWrapper()
        status.authorizationStatus = { authorized ? .authorized : .denied }
        Current.focusFilter = filter
        Current.focusStatus = status
        defer {
            Current.focusFilter = previousFilter
            Current.focusStatus = previousStatus
        }
        try await SettingsTestDatabase.with({ db in
            for name in names {
                try FocusName(name: name).insert(db)
            }
        }, body)
    }

    @Test func showsNamesWarningsAndFollowsEveryLink() async throws {
        try await withFocus(names: ["Sleep", "Work"], active: "Work", authorized: false) { _ in
            let harness = await SettingsScreenHarness.show(FocusSettingsView())
            // Header, how it works, two names and the add button, the reported name and two warnings.
            await #expect(harness.waitUntil { harness.rows.count >= 8 })

            // How it works, the sensor list and the permissions screen.
            var opened = 0
            for row in [IndexPath(item: 0, section: 1)] + harness.rows.filter({ $0.section == 3 && $0.item > 0 }) {
                if await harness.push(row) {
                    opened += 1
                    await harness.pop()
                }
            }
            #expect(opened == 3)
            await harness.close()
        }
    }

    @Test func addsANameThroughTheAlert() async throws {
        try await withFocus(names: [], active: nil, authorized: true) { database in
            let harness = await SettingsScreenHarness.show(FocusSettingsView())
            // The empty state and the add button.
            await #expect(harness.waitUntil { harness.rows.filter { $0.section == 2 }.count == 2 })

            await harness.tapRow(IndexPath(item: 1, section: 2))
            await #expect(harness.waitUntil(timeout: 5) { harness.alert != nil })
            if let field = harness.alert?.textFields?.first {
                field.text = "Gym"
                field.sendActions(for: .editingChanged)
            }
            await harness.settle()
            await harness.tapAlertButton(L10n.addButtonLabel)

            let names = try await database.read { db in try FocusName.fetchAll(db).map(\.name) }
            #expect(names == ["Gym"])
            await harness.close()
        }
    }

    /// The screen offers its section titles to the settings search.
    @Test func offersItsSectionsToSearch() {
        #expect(FocusSettingsView.settingsSearchEntries.map(\.title) == [
            L10n.Focus.Names.header,
            L10n.Focus.Names.add,
            L10n.Focus.HowItWorks.title,
        ])
    }
}
