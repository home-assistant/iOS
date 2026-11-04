@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct NativeTabBarItemLabelSnapshotTests {
    @Test func rendersTheProfileAvatarForAProfileItemWithTheAppsDefaultAccentColor() {
        let item = NativeTabBarItem(kind: .panel(.init(
            id: "profile",
            kind: .profile,
            title: "Bruno",
            icon: .material(.accountIcon)
        )))
        assertLightDarkSnapshots(
            of: List { NativeTabBarItemLabel(item: item, server: ServerFixture.standard, user: nil) },
            layout: .fixed(width: 300, height: 80)
        )
    }
}
