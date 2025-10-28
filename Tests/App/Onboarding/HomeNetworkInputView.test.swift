@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing

struct HomeNetworkInputViewTests {
    @MainActor @Test func testEmptyNetworkSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                HomeNetworkInputView(
                    onNext: { _ in
                        // Next action for testing
                    }
                )
                .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view, named: "empty-network")
    }
}
