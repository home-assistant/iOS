@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing

struct LocalAccessOnlyDisclaimerViewTests {
    @MainActor @Test func testSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                LocalAccessOnlyDisclaimerView {
                    // Continue action for testing
                }
                .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view)
    }
}