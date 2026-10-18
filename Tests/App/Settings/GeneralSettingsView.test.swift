@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct GeneralSettingsViewTests {
    /// Building the screen is what constructs the Enhanced Security row, which is the only place
    /// that setting is reachable from.
    @Test func buildsTheEnhancedWebSecurityRow() {
        _ = GeneralSettingsView().body
    }

    /// "Remember last page" lives here again, so search has to lead here for it, except on Catalyst,
    /// where the toggle is not shown.
    @Test func searchIndexesRememberLastPageWhereTheToggleShows() {
        let titles = GeneralSettingsView.settingsSearchEntries.map(\.title)
        #expect(titles.contains(L10n.SettingsDetails.General.Restoration.title) == !Current.isCatalyst)
    }
}
