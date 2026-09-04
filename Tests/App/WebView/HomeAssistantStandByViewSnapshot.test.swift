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
struct HomeAssistantStandByViewSnapshotTests {
    @MainActor @Test func clientCertificateRequiredSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        assertLightDarkWindowSnapshots(style: .clientCertificateRequired, named: "client-certificate-required")
    }

    @MainActor @Test func clientCertificateRejectedSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        assertLightDarkWindowSnapshots(style: .clientCertificateRejected, named: "client-certificate-rejected")
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
    ) {
        for interfaceStyle in [UIUserInterfaceStyle.light, .dark] {
            assertSnapshot(
                of: render(style: style, interfaceStyle: interfaceStyle),
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

    @MainActor
    private func render(style: WebViewEmptyStateStyle, interfaceStyle: UIUserInterfaceStyle) -> UIImage {
        let server = HomeAssistantStandByView.previewServer(
            name: "mTLS Server",
            configuredURLTypes: [.external],
            activeURLType: .external
        )
        let controller = UIHostingController(
            rootView: HomeAssistantStandByView(
                server: server,
                emptyState: HomeAssistantStandByView.previewEmptyState(style: style, server: server)
            )
            // The stand-by content fades in on appear; snapshot its settled state rather than the fade.
            .transaction { $0.disablesAnimations = true }
        )
        controller.overrideUserInterfaceStyle = interfaceStyle

        // The size the other empty-state snapshots use (an iPhone 13 portrait layout).
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)))
        window.overrideUserInterfaceStyle = interfaceStyle
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        // Appearing is what reveals the content, and that state change needs a turn of the run loop.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return image
    }
}
