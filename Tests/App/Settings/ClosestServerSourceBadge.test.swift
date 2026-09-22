@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

struct ClosestServerSourceBadgeTests {
    /// A fixed layout rather than `.sizeThatFits`: the badge's job is to keep its shape when
    /// something else wants the width, so it is measured in a frame wider than it needs.
    @MainActor
    @Test func badgeSources() async throws {
        assertLightDarkSnapshots(
            of: VStack(spacing: DesignSystem.Spaces.two) {
                ClosestServerSourceBadge(source: .homeNetwork)
                ClosestServerSourceBadge(source: .location(distance: 1200))
            }
            .frame(width: 320, height: 120),
            layout: .sizeThatFits
        )
    }
}
