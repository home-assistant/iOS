@testable import HomeAssistant
import Shared
import XCTest

final class WebViewEmptyStateStyleTests: XCTestCase {
    func testClientCertificateStylesComeFromTheIssue() {
        XCTAssertEqual(WebViewEmptyStateStyle(clientCertificateIssue: .required), .clientCertificateRequired)
        XCTAssertEqual(WebViewEmptyStateStyle(clientCertificateIssue: .rejected), .clientCertificateRejected)
    }

    func testClientCertificateRequiredCopyAndLayout() {
        let style = WebViewEmptyStateStyle.clientCertificateRequired

        XCTAssertEqual(style.title, L10n.WebView.EmptyState.ClientCertificate.Required.title)
        assertClientCertificateLayout(of: style)
    }

    func testClientCertificateRejectedCopyAndLayout() {
        let style = WebViewEmptyStateStyle.clientCertificateRejected

        XCTAssertEqual(style.title, L10n.WebView.EmptyState.ClientCertificate.Rejected.title)
        assertClientCertificateLayout(of: style)
    }

    func testOtherStylesAreNotClientCertificateIssues() {
        for style in [
            WebViewEmptyStateStyle.disconnected,
            .inFlight,
            .unauthenticated,
            .loggedOut,
            .recoveredServerNeedingReauthentication,
        ] {
            XCTAssertFalse(style.isClientCertificateIssue, "expected \(style) not to be a certificate issue")
        }
    }

    /// Both certificate styles share the re-authentication layout: settings in the header, a single
    /// warning-colored import action, and server-specific body copy that the message view builds.
    private func assertClientCertificateLayout(
        of style: WebViewEmptyStateStyle,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(style.isClientCertificateIssue, file: file, line: line)
        XCTAssertEqual(style.body, "", file: file, line: line)
        XCTAssertNil(style.complementaryMessage, file: file, line: line)
        XCTAssertEqual(
            style.primaryButtonTitle,
            L10n.WebView.EmptyState.ClientCertificate.importButton,
            file: file,
            line: line
        )
        XCTAssertEqual(style.secondaryButtonTitle, L10n.WebView.EmptyState.openSettingsButton, file: file, line: line)
        XCTAssertEqual(style.urlPickerTitle, L10n.WebView.EmptyState.reauthenticateButton, file: file, line: line)
        XCTAssertEqual(
            style.leadingHeaderAccessory,
            WebViewEmptyStateStyle.HeaderAccessory.settings,
            file: file,
            line: line
        )
        XCTAssertEqual(
            style.trailingHeaderAccessory,
            WebViewEmptyStateStyle.HeaderAccessory.none,
            file: file,
            line: line
        )
        XCTAssertFalse(style.showsSecondarySettingsButton, file: file, line: line)
        XCTAssertTrue(style.primaryActionRequiresAttention, file: file, line: line)
        XCTAssertTrue(style.showsServerPicker, file: file, line: line)
    }
}
