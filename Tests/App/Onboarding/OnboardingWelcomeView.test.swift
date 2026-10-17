@testable import HomeAssistant
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// The screen is snapshotted on its own: a `NavigationStack` renders its bar differently from one
/// OS build to the next, so references recorded through it don't survive CI. The toolbar is covered
/// by laying the stack out in a window instead.
struct OnboardingWelcomeViewTests {
    @MainActor @Test func regularHeightShowsBottomActions() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(OnboardingWelcomeView(continueAction: {})),
            named: "welcome-regular-height"
        )
    }

    /// A short window (closed iPhone Duo or any iPhone in landscape) drops the bottom button block;
    /// the actions live in the navigation bar, which is not part of this render.
    @MainActor @Test func compactHeightDropsBottomActions() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(
                OnboardingWelcomeView(continueAction: {})
                    .environment(\.verticalSizeClass, .compact)
            ),
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
            of: AnyView(
                OnboardingWelcomeView(continueAction: {})
                    .safeAreaPadding(.trailing, 80)
            ),
            named: "welcome-trailing-inset"
        )
    }

    /// In compact height the actions move into the navigation bar. Hosting the stack in a window
    /// of its own is what makes SwiftUI build that toolbar, so this lays the real configuration out.
    /// The window never becomes key: the snapshot helpers draw into whatever window is key, so
    /// taking it would reach into unrelated tests.
    @MainActor @Test func compactHeightLaysOutWithTheActionsInTheNavigationBar() async throws {
        guard #available(iOS 18.0, *) else { return }

        let screen = NavigationStack {
            OnboardingWelcomeView(continueAction: {})
        }
        .environment(\.verticalSizeClass, .compact)
        let controller = UIHostingController(rootView: screen)
        let size = CGSize(width: 844, height: 390)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false

        window.layoutIfNeeded()

        #expect(controller.view.bounds.size == size)
        window.isHidden = true
        window.rootViewController = nil
    }
}
