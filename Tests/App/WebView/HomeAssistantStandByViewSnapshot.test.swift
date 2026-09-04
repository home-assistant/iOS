@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing

/// The stand-by view is what the app actually shows over the web view, so the certificate empty states
/// are snapshotted here as the user sees them, on top of the `WebViewEmptyStateView` variants.
struct HomeAssistantStandByViewSnapshotTests {
    /// The loading logo behind the empty state is a web view, which the snapshot waits on; give it
    /// room to finish loading on a busy CI runner.
    private static let snapshotTimeout: TimeInterval = 30

    @MainActor @Test func clientCertificateRequiredSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        assertLightDarkSnapshots(
            of: makeView(style: .clientCertificateRequired),
            named: "client-certificate-required",
            timeout: Self.snapshotTimeout
        )
    }

    @MainActor @Test func clientCertificateRejectedSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        assertLightDarkSnapshots(
            of: makeView(style: .clientCertificateRejected),
            named: "client-certificate-rejected",
            timeout: Self.snapshotTimeout
        )
    }

    @MainActor
    private func makeView(style: WebViewEmptyStateStyle) -> some View {
        let server = HomeAssistantStandByView.previewServer(
            name: "mTLS Server",
            configuredURLTypes: [.external],
            activeURLType: .external
        )
        return HomeAssistantStandByView(
            server: server,
            emptyState: HomeAssistantStandByView.previewEmptyState(style: style, server: server)
        )
        // The stand-by content fades in on appear; snapshot its settled state rather than the fade.
        .transaction { $0.disablesAnimations = true }
    }
}
