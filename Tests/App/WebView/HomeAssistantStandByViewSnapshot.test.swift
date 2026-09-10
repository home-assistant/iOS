@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
import XCTest

/// The stand-by view is what the app actually shows over the web view, so the certificate empty states
/// are snapshotted here as the user sees them, on top of the `WebViewEmptyStateView` variants.
///
/// The loading logo behind the empty state is a web view, which the snapshot library waits on before
/// rendering a view and which never finishes loading in a test, so the view is drawn from a live window
/// instead of going through the library's view renderer.
/// The test and image names carry a "stand-by" prefix: Xcode copies every reference image into the
/// test bundle, so file names have to be unique across suites, and the `WebViewEmptyStateView` suite
/// already records the plain certificate names.
@Suite(.serialized)
struct HomeAssistantStandByViewSnapshotTests {
    @MainActor @Test func standByClientCertificateRequiredSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        try await assertLightDarkWindowSnapshots(
            style: .clientCertificateRequired,
            named: "stand-by-client-certificate-required"
        )
    }

    @MainActor @Test func standByClientCertificateRejectedSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        try await assertLightDarkWindowSnapshots(
            style: .clientCertificateRejected,
            named: "stand-by-client-certificate-rejected"
        )
    }

    /// The web view's failures arrive while the loading state is already up, so the empty state usually
    /// comes in through a change rather than on appear. It has to settle to the same screen either way.
    @MainActor @Test func standByEmptyStateArrivingAfterAppearRendersLikeStartingWithIt() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let fromTheStart = try await render(style: .clientCertificateRequired, interfaceStyle: .light)
        let afterLoading = try await render(
            style: .clientCertificateRequired,
            interfaceStyle: .light,
            startsLoading: true,
            expectedImage: fromTheStart
        )

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
        style: WebViewEmptyStateStyle,
        named name: String,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) async throws {
        for interfaceStyle in [UIUserInterfaceStyle.light, .dark] {
            let image = try await render(style: style, interfaceStyle: interfaceStyle)
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
        style: WebViewEmptyStateStyle,
        interfaceStyle: UIUserInterfaceStyle,
        startsLoading: Bool = false,
        expectedImage: UIImage? = nil
    ) async throws -> UIImage {
        let server = HomeAssistantStandByView.previewServer(
            name: "mTLS Server",
            configuredURLTypes: [.external],
            activeURLType: .external
        )
        let emptyState = HomeAssistantStandByView.previewEmptyState(style: style, server: server)
        func makeView(emptyState: WebFrontendOverlayState.EmptyStateContent?) -> HomeAssistantStandByView {
            HomeAssistantStandByView(
                server: server,
                emptyState: emptyState,
                // The content fades in on appear and on change; render its settled state rather than the fade.
                contentFadeAnimation: nil
            )
        }
        let controller = UIHostingController(rootView: makeView(emptyState: startsLoading ? nil : emptyState))
        controller.overrideUserInterfaceStyle = interfaceStyle
        // On the host app's scene, so the window is a real one that reports appearance; a window
        // without a scene never appears, and the content (which fades in on appear) stays hidden.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: CGSize(width: 390, height: 844))
        window.overrideUserInterfaceStyle = interfaceStyle
        window.rootViewController = controller
        let previousKeyWindow = scene?.windows.first { $0.isKeyWindow }
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        window.makeKeyAndVisible()
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        window.layoutIfNeeded()
        // Suspend until display frames run; a nested RunLoop can starve queued SwiftUI work.
        try await nextRenderedFrame()
        window.layoutIfNeeded()

        if startsLoading {
            // Preserve view identity so the actual change handler is exercised.
            controller.rootView = makeView(emptyState: emptyState)
            window.layoutIfNeeded()
            try await nextRenderedFrame()
        }

        func capture() -> UIImage {
            window.layoutIfNeeded()
            return UIGraphicsImageRenderer(bounds: window.bounds).image { context in
                window.layer.render(in: context.cgContext)
            }
        }

        var image = capture()
        if let expectedImage {
            let diffing = Diffing<UIImage>.image(precision: 0.96, perceptualPrecision: 0.96)
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            // The expected rendered state, not elapsed sleep time, is the completion signal.
            // A persistent mismatch is returned to the assertion above and still fails the test.
            while diffing.diff(expectedImage, image) != nil, ContinuousClock.now < deadline {
                try await nextRenderedFrame()
                image = capture()
            }
        }
        return image
    }

    @MainActor
    private func nextRenderedFrame() async throws {
        let frame = DisplayFrame()
        let link = CADisplayLink(target: frame, selector: #selector(DisplayFrame.tick))
        link.add(to: .main, forMode: .common)
        defer { link.invalidate() }
        let result = await XCTWaiter.fulfillment(of: [frame.completed], timeout: 5)
        guard result == .completed else { throw RenderError.noDisplayFrame }
    }

    private enum RenderError: Error {
        case noDisplayFrame
    }

    @MainActor
    private final class DisplayFrame: NSObject {
        let completed = XCTestExpectation(description: "hosting window rendered a frame")
        private var ticks = 0

        @objc func tick(_ link: CADisplayLink) {
            ticks += 1
            // The first callback precedes rendering; the next observes that frame's commit.
            guard ticks == 2 else { return }
            link.invalidate()
            completed.fulfill()
        }
    }
}
