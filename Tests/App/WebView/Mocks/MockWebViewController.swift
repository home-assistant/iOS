import Foundation
@testable import HomeAssistant
import Shared
import UIKit

final class MockWebViewController: WebViewControllerProtocol {
    var webViewExternalMessageHandler: WebViewExternalMessageHandlerProtocol
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var traitCollection: UITraitCollection = .init()
    var server: Server = ServerFixture.standard
    var connectionState: FrontEndConnectionState = .connected
    var overlayedController: UIViewController?

    var presentOverlayControllerCalled = false
    var presentControllerCalled = false
    var evaluateJavaScriptCalled = false
    var lastEvaluatedJavaScriptScript: String?
    var lastEvaluatedJavaScriptCompletion: ((Any?, (any Error)?) -> Void)?
    var dismissControllerAboveOverlayControllerCalled = false
    var dismissOverlayControllerCalled = false
    var dismissOverlayControllerLastAnimated = false
    var dismissOverlayControllerLastCompletion: (() -> Void)?
    var updateSettingsButtonCalled = false
    var lastSettingButtonState: String?
    var navigateToPathCalled = false
    var lastNavigateToPathPath: String?
    var updateImprovEntryViewCalled = false
    var lastUpdateImprovEntryViewState = false
    var refreshCalled = false
    var presentAlertControllerCalled = false

    init() {
        self.webViewExternalMessageHandler = MockWebViewExternalMessageHandler()
    }

    func load(request: URLRequest) {
        // Simulate loading a request
    }

    func showSettingsViewController() {
        // Simulate showing settings
    }

    func openDebug() {
        // Simulate opening debug view
    }

    func goBack() {
        // Simulate going back
    }

    func goForward() {
        // Simulate going forward
    }

    func styleUI() {
        // Simulate styling UI
    }

    func presentOverlayController(controller: UIViewController, animated: Bool) {
        presentOverlayControllerCalled = true
        overlayedController = controller
    }

    func evaluateJavaScript(_ script: String, completion: ((Any?, (any Error)?) -> Void)?) {
        evaluateJavaScriptCalled = true
        lastEvaluatedJavaScriptScript = script
        lastEvaluatedJavaScriptCompletion = completion
    }

    func dismissOverlayController(animated: Bool, completion: (() -> Void)?) {
        dismissOverlayControllerCalled = true
        dismissOverlayControllerLastAnimated = animated
        dismissOverlayControllerLastCompletion = completion
    }

    func dismissControllerAboveOverlayController() {
        dismissControllerAboveOverlayControllerCalled = true
    }

    func updateFrontendConnectionState(state: String) {
        updateSettingsButtonCalled = true
        lastSettingButtonState = state
    }

    func updateImprovEntryView(show: Bool) {
        updateImprovEntryViewCalled = true
        lastUpdateImprovEntryViewState = show
    }

    func navigateToPath(path: String) {
        navigateToPathCalled = true
        lastNavigateToPathPath = path
    }

    func refresh() {
        refreshCalled = true
    }

    func refreshIfDisconnected() {
        // Simulate conditional refresh
    }

    func presentAlertController(controller: UIViewController, animated: Bool) {
        presentAlertControllerCalled = true
    }
}
