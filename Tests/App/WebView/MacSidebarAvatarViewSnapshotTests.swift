@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct MacSidebarAvatarViewSnapshotTests {
    @Test func avatarRendersWithTheAppsDefaultAccentColorWhenNoneIsGiven() {
        assertLightDarkSnapshots(
            of: MacSidebarAvatarView(server: ServerFixture.standard, title: "Bruno", user: nil, size: 20),
            layout: .fixed(width: 40, height: 40)
        )
    }
}
