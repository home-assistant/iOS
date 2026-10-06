@testable import HomeAssistant
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct OnboardingWelcomeViewTests {
    @MainActor @Test func regularHeightShowsBottomActions() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(NavigationStack {
                OnboardingWelcomeView(continueAction: {})
            }),
            drawHierarchyInKeyWindow: true,
            named: "welcome-regular-height"
        )
    }

    /// A short window (closed iPhone Duo or any iPhone in landscape) moves the actions into the
    /// navigation bar and drops the bottom button block.
    @MainActor @Test func compactHeightShowsToolbarActions() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(NavigationStack {
                OnboardingWelcomeView(continueAction: {})
                    .environment(\.verticalSizeClass, .compact)
            }),
            drawHierarchyInKeyWindow: true,
            layout: .device(config: .iPhone13(.landscape)),
            named: "welcome-compact-height"
        )
    }
}
