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
}
