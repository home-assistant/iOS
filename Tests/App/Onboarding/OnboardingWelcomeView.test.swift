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
            layout: .device(config: .iPhone13(.landscape)),
            named: "welcome-compact-height"
        )
    }

    /// A vertical bar or camera on one side (iPhone Duo) insets only that edge; the content has to
    /// read as centered on the whole display, not on the inset region.
    @MainActor @Test func asymmetricHorizontalInsetKeepsContentCentered() async throws {
        guard #available(iOS 18.0, *) else { return }

        // The renderer has no device inset to offer, so the inset is grown from the SwiftUI side:
        // safe area padding is what the screen reads as its trailing safe area inset.
        assertLightDarkSnapshots(
            of: AnyView(NavigationStack {
                OnboardingWelcomeView(continueAction: {})
                    .safeAreaPadding(.trailing, 80)
            }),
            named: "welcome-trailing-inset"
        )
    }
}
