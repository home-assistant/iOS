@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct MacSidebarRowSnapshotTests {
    @Test func rendersWithTheAppsDefaultAccentColorWhenNoneIsGiven() {
        assertLightDarkSnapshots(
            of: MacSidebarRow(
                item: .init(
                    id: "energy",
                    kind: .panel(path: "/energy"),
                    title: "Energy",
                    icon: .material(.lightningBoltIcon),
                    badge: 3
                ),
                isSelected: false,
                server: ServerFixture.standard,
                user: nil
            ) {}
                .frame(width: 240, height: 60),
            layout: .fixed(width: 240, height: 60)
        )
    }

    @Test func avatarRendersWithTheAppsDefaultAccentColorWhenNoneIsGiven() {
        assertLightDarkSnapshots(
            of: MacSidebarAvatarView(server: ServerFixture.standard, title: "Bruno", user: nil, size: 20),
            layout: .fixed(width: 40, height: 40)
        )
    }
}
