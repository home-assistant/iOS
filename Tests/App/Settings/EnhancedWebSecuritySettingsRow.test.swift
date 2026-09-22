@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct EnhancedWebSecuritySettingsRowTests {
    @Test func testUI() async throws {
        assertLightDarkSnapshots(
            of: List { EnhancedWebSecuritySettingsRow(viewModel: .init(isRelevant: true, isEnabled: false)) },
            // The footer explains the trade-off at length, so the row needs more than a list cell.
            layout: .fixed(width: 390, height: 420)
        )
    }

    /// An HTTPS-only setup has nothing to opt out of, so the row renders no section at all.
    @Test func rendersNothingWhenNotRelevant() async throws {
        assertLightDarkSnapshots(
            of: List { EnhancedWebSecuritySettingsRow(viewModel: .init(isRelevant: false, isEnabled: false)) },
            layout: .fixed(width: 390, height: 200),
            named: "not-relevant"
        )
    }
}
