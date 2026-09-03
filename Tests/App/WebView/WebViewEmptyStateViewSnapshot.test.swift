@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing

struct WebViewEmptyStateViewSnapshotTests {
    @MainActor @Test func clientCertificateRequiredSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        assertLightDarkSnapshots(
            of: makeView(style: .clientCertificateRequired),
            named: "client-certificate-required"
        )
    }

    @MainActor @Test func clientCertificateRejectedSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        assertLightDarkSnapshots(
            of: makeView(style: .clientCertificateRejected),
            named: "client-certificate-rejected"
        )
    }

    @MainActor
    private func makeView(style: WebViewEmptyStateStyle) -> some View {
        WebViewEmptyStateView(
            style: style,
            server: ServerFixture.standard,
            retryAction: {},
            settingsAction: {},
            errorDetailsAction: {},
            reauthAction: { _ in },
            clientCertificateAction: {},
            serverSelectionAction: { _ in },
            dismissAction: {}
        )
    }
}
