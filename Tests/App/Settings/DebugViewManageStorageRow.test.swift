@testable import HomeAssistant
import Shared
import SwiftUI
import Testing

@MainActor
struct DebugViewManageStorageRowTests {
    /// Builds the screen so the Manage Storage row is constructed for real. `NavigationLink`
    /// evaluates both its destination and its label eagerly, so this covers the row's whole
    /// wiring, including that `ManageStorageViewModel` can be built from the main actor the way
    /// the row builds it.
    @Test func theDebugScreenBuildsTheManageStorageRow() {
        _ = DebugView().body
    }

    @Test func theManageStorageRowIsReachableFromSettingsSearch() {
        let titles = DebugView.settingsSearchEntries.map(\.title)

        #expect(titles.contains(L10n.Settings.Debugging.ManageStorage.title))
    }
}
