@testable import HomeAssistant
import Shared
import XCTest

@MainActor
final class WebViewEmptyStateActionButtonsTests: XCTestCase {
    func testClientCertificateStylesRunTheImportAction() {
        for style in [WebViewEmptyStateStyle.clientCertificateRequired, .clientCertificateRejected] {
            var imported = false
            var retried = false
            var reauthenticated = false
            let sut = WebViewEmptyStateActionButtons(
                style: style,
                availableReauthURLTypes: [.external],
                retryAction: { retried = true },
                settingsAction: {},
                errorDetailsAction: {},
                reauthAction: { _ in reauthenticated = true },
                clientCertificateAction: { imported = true }
            )

            sut.performPrimaryAction()

            XCTAssertTrue(imported, "expected \(style) to open the certificate import")
            XCTAssertFalse(retried)
            XCTAssertFalse(reauthenticated)
        }
    }

    /// Surfaces that show the certificate styles without wiring an import (previews, the recovered-server
    /// screen) get a primary button that does nothing rather than one that retries or re-authenticates.
    func testClientCertificateStylesWithoutAnImportActionDoNothing() {
        var retried = false
        var reauthenticated = false
        let sut = WebViewEmptyStateActionButtons(
            style: .clientCertificateRequired,
            availableReauthURLTypes: [.external],
            retryAction: { retried = true },
            settingsAction: {},
            errorDetailsAction: {},
            reauthAction: { _ in reauthenticated = true }
        )

        sut.performPrimaryAction()

        XCTAssertFalse(retried)
        XCTAssertFalse(reauthenticated)
    }

    func testDisconnectedStyleRetriesWithoutNeedingAnImportAction() {
        var retried = false
        let sut = WebViewEmptyStateActionButtons(
            style: .disconnected,
            availableReauthURLTypes: [],
            retryAction: { retried = true },
            settingsAction: {},
            errorDetailsAction: {},
            reauthAction: { _ in }
        )

        sut.performPrimaryAction()

        XCTAssertTrue(retried)
    }
}
