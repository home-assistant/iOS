import XCTest

/// Drives onboarding through a reverse proxy that requires a client certificate (mTLS): the app has
/// to notice the requirement, import the certificate the flow hands it, and present it on the login
/// web view, the registration and the WebSocket behind the frontend.
///
/// Counterpart of `.maestro/onboarding-mtls.yaml` in home-assistant/android. Needs the proxy from
/// `.github/e2e/mtls` in front of the instance, and the lane's `mtls_certificates:` option.
final class MTLSOnboardingE2ETests: XCTestCase {
    private var app: XCUIApplication!
    private var flow: E2EFlow!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCTAssertFalse(
            E2EFlow.Instance.clientCertificateFile.isEmpty,
            "E2E_CLIENT_CERTIFICATE_FILE is not set: run this flow through `fastlane e2e mtls_certificates:<dir>`"
        )
        app = XCUIApplication()
        app.launchArguments = E2EFlow.clientCertificateLaunchArguments
        app.launch()
        flow = E2EFlow(app: app)
    }

    func testOnboardingThroughMTLSProxyImportsCertificateAndFrontendOpensNativeSettings() {
        flow.onboard(importingClientCertificate: true)
        flow.openNativeSettingsFromFrontend()
    }
}
