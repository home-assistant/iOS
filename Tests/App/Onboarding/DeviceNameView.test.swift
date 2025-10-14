@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing

struct DeviceNameViewTests {
    @MainActor @Test func testEmptyStateSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            DeviceNameView(errorMessage: nil) { _ in
                // Save action for testing
            } cancelAction: {
                // Cancel action for testing
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        )
        assertLightDarkSnapshots(of: view, named: "empty-state")
    }

    @MainActor @Test func testWithPrefilledNameSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = DeviceNameView(errorMessage: nil) { _ in
            // Save action for testing
        } cancelAction: {
            // Cancel action for testing
        }
        
        #if DEBUG
        // Use the debug method to set a prefilled name for testing
        view.setDeviceName("iPhone")
        #endif
        
        let testView = AnyView(
            view.toolbarVisibility(.hidden, for: .navigationBar)
        )
        assertLightDarkSnapshots(of: testView, named: "with-prefilled-name")
    }

    @MainActor @Test func testWithErrorMessageSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            DeviceNameView(errorMessage: "Device name is too short") { _ in
                // Save action for testing
            } cancelAction: {
                // Cancel action for testing
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        )
        assertLightDarkSnapshots(of: view, named: "with-error-message")
    }
}
