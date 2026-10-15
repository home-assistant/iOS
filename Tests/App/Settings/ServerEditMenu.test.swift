import Foundation
@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

/// Covers the toolbar pencil menu and the pill menu items it shares options with.
@Suite(.serialized)
@MainActor
struct ServerEditMenuTests {
    @Test func pencilMenu() async throws {
        assertLightDarkSnapshots(
            of: ServerEditMenu { _ in }.padding(),
            layout: .fixed(width: 120, height: 80)
        )
    }

    @Test func pillMenuItemsBuild() {
        _ = ServerDetailsRowView.URLPillMenuItems(copyValue: "http://homeassistant.local:8123", onEdit: {}).body
        _ = ServerDetailsRowView.URLPillMenuItems(copyValue: nil, onEdit: {}).body
    }
}
