@testable import HomeAssistant
import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct OnboardingServersListViewTests {
    @MainActor @Test func regularHeightShowsCenteredLoader() async throws {
        guard #available(iOS 18.0, *) else { return }
        Current.bonjour = { MockBonjour() }

        assertLightDarkSnapshots(
            of: AnyView(NavigationStack {
                OnboardingServersListView(onboardingStyle: .secondary, presenter: OnboardingAuthPresenter())
            }),
            named: "servers-list-regular-height"
        )
    }

    /// A short window (closed iPhone Duo or any iPhone in landscape) moves the title into the
    /// navigation bar and leaves the height to the loader.
    @MainActor @Test func compactHeightShowsTitleInToolbar() async throws {
        guard #available(iOS 18.0, *) else { return }
        Current.bonjour = { MockBonjour() }

        assertLightDarkSnapshots(
            of: AnyView(NavigationStack {
                OnboardingServersListView(onboardingStyle: .secondary, presenter: OnboardingAuthPresenter())
                    .environment(\.verticalSizeClass, .compact)
            }),
            layout: .device(config: .iPhone13(.landscape)),
            named: "servers-list-compact-height"
        )
    }
}
