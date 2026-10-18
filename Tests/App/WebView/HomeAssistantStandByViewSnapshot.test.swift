@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// The stand-by view is what the app actually shows over the web view, so the certificate empty states
/// are snapshotted here as the user sees them, on top of the `WebViewEmptyStateView` variants.
///
/// The loading logo behind the empty state is a web view, which the snapshot library waits on before
/// rendering a view and which never finishes loading in a test, so the view is drawn from a live window
/// instead of going through the library's view renderer.
/// The test and image names carry a "stand-by" prefix: Xcode copies every reference image into the
/// test bundle, so file names have to be unique across suites, and the `WebViewEmptyStateView` suite
/// already records the plain certificate names.
struct HomeAssistantStandByViewSnapshotTests {
    private static let iPhoneDuoSize = CGSize(width: 466, height: 678)
    private static let iPhoneDuoVerticalBarInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 84)

    @MainActor @Test func standByClientCertificateRequiredSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        await assertLightDarkWindowSnapshots(
            style: .clientCertificateRequired,
            named: "stand-by-client-certificate-required"
        )
    }

    @MainActor @Test func standByClientCertificateRejectedSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        await assertLightDarkWindowSnapshots(
            style: .clientCertificateRejected,
            named: "stand-by-client-certificate-rejected"
        )
    }

    @MainActor @Test func standByDisconnectedWithTrailingInsetIsCenteredOnTheDisplay() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        await assertLightDarkWindowSnapshots(
            style: .disconnected,
            windowSize: Self.iPhoneDuoSize,
            additionalSafeAreaInsets: Self.iPhoneDuoVerticalBarInsets,
            named: "stand-by-disconnected-trailing-inset"
        )
    }

    @MainActor @Test func standByStuckLoadingWithTrailingInsetIsCenteredOnTheDisplay() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        StandByOHFBrandingState.shared.markStandByDismissed()

        await assertLightDarkWindowSnapshots(
            style: nil,
            windowSize: Self.iPhoneDuoSize,
            additionalSafeAreaInsets: Self.iPhoneDuoVerticalBarInsets,
            named: "stand-by-stuck-loading-trailing-inset"
        )
    }

    /// The web view's failures arrive while the loading state is already up, so the empty state usually
    /// comes in through a change rather than on appear. It has to settle to the same screen either way.
    @MainActor @Test func standByEmptyStateArrivingAfterAppearRendersLikeStartingWithIt() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let fromTheStart = await render(style: .clientCertificateRequired, interfaceStyle: .light)
        let afterLoading = await render(style: .clientCertificateRequired, interfaceStyle: .light, startsLoading: true)

        let diffing = Diffing<UIImage>.image(precision: 0.96, perceptualPrecision: 0.96)
        if let difference = diffing.diff(fromTheStart, afterLoading) {
            Issue.record("The late-arriving empty state rendered differently: \(difference.0)")
        }
    }

    /// The app builds the view with its default fade; that configuration has to host and lay out too.
    @MainActor @Test func defaultConfigurationLaysOut() async throws {
        let server = HomeAssistantStandByView.previewServer(
            name: "mTLS Server",
            configuredURLTypes: [.external],
            activeURLType: .external
        )
        let controller = UIHostingController(rootView: HomeAssistantStandByView(
            server: server,
            emptyState: HomeAssistantStandByView.previewEmptyState(style: .clientCertificateRequired, server: server)
        ))
        controller.view.frame = CGRect(origin: .zero, size: CGSize(width: 390, height: 844))

        controller.view.layoutIfNeeded()

        #expect(controller.view.bounds.size == CGSize(width: 390, height: 844))
    }

    @MainActor
    private func assertLightDarkWindowSnapshots(
        style: WebViewEmptyStateStyle?,
        windowSize: CGSize = CGSize(width: 390, height: 844),
        additionalSafeAreaInsets: UIEdgeInsets = .zero,
        named name: String,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) async {
        for interfaceStyle in [UIUserInterfaceStyle.light, .dark] {
            let image = await render(
                style: style,
                interfaceStyle: interfaceStyle,
                windowSize: windowSize,
                additionalSafeAreaInsets: additionalSafeAreaInsets
            )
            assertSnapshot(
                of: image,
                as: .image(precision: 0.96, perceptualPrecision: 0.96),
                named: "\(name)-\(interfaceStyle == .light ? "light" : "dark")",
                fileID: fileID,
                file: file,
                testName: testName,
                line: line,
                column: column
            )
        }
    }

    /// Draws the stand-by view showing `style`, either from the start or, with `startsLoading`, arriving
    /// after the loading state has already appeared.
    @MainActor
    private func render(
        style: WebViewEmptyStateStyle?,
        interfaceStyle: UIUserInterfaceStyle,
        startsLoading: Bool = false,
        windowSize: CGSize = CGSize(width: 390, height: 844),
        additionalSafeAreaInsets: UIEdgeInsets = .zero
    ) async -> UIImage {
        let server = HomeAssistantStandByView.previewServer(
            name: "mTLS Server",
            configuredURLTypes: [.external],
            activeURLType: .external
        )
        let emptyState = style.map { HomeAssistantStandByView.previewEmptyState(style: $0, server: server) }
        func makeView(emptyState: WebFrontendOverlayState.EmptyStateContent?) -> HomeAssistantStandByView {
            guard style == nil else {
                return HomeAssistantStandByView(
                    server: server,
                    emptyState: emptyState,
                    // The content fades in on appear and on change; render its settled state rather than the fade.
                    contentFadeAnimation: nil
                )
            }
            return HomeAssistantStandByView(
                server: server,
                emptyState: nil,
                onCleanCacheAndReload: {},
                delayedSettingsButtonDelay: .zero,
                cleanCacheButtonDelay: .zero,
                contentFadeAnimation: nil
            )
        }
        let controller = UIHostingController(rootView: makeView(emptyState: startsLoading ? nil : emptyState))
        controller.overrideUserInterfaceStyle = interfaceStyle
        controller.additionalSafeAreaInsets = additionalSafeAreaInsets
        // On the host app's scene, so the window is a real one that reports appearance; a window
        // without a scene never appears, and the content (which fades in on appear) stays hidden.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: windowSize)
        window.overrideUserInterfaceStyle = interfaceStyle
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        window.layoutIfNeeded()
        // Let the appear-driven state changes (the content fade-in) apply before drawing.
        try? await Task.sleep(for: .seconds(1))
        window.layoutIfNeeded()

        if startsLoading {
            // Same view identity, so the change handler moves it from loading to the empty state.
            controller.rootView = makeView(emptyState: emptyState)
            window.layoutIfNeeded()
            try? await Task.sleep(for: .seconds(1))
            window.layoutIfNeeded()
        }

        // A test window is not on a display, so `drawHierarchy` has nothing to draw; the layer tree
        // renders the same content without one.
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in
            window.layer.render(in: context.cgContext)
        }
        window.isHidden = true
        return image
    }
}
