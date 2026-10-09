@testable import HomeAssistant
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct NotificationPermissionRequestViewTests {
    /// The prompt is sheet content now, so it is rendered at a sheet's medium height rather than full
    /// screen.
    @MainActor @Test func sheetContentSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(NotificationPermissionRequestView()),
            layout: .fixed(width: 390, height: 420),
            named: "notification-permission-sheet"
        )
    }
}
