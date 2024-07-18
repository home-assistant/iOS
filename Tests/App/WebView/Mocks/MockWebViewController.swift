import Foundation
@testable import HomeAssistant
import Shared
import UIKit

final class MockWebViewController: WebViewControllerProtocol {
    var server: Server = ServerFixture.standard
    var overlayAppController: UIViewController?

    var presentOverlayControllerCalled = false
    var presentControllerCalled = false
    var evaluateJavaScriptCalled = false

    var lastPresentedController: UIViewController?
    var lastPresentedControllerAnimated: Bool = false
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

    func presentOverlayController(controller: UIViewController) {
        presentOverlayControllerCalled = true
        overlayAppController = controller
    }

    func presentController(_ controller: UIViewController, animated: Bool) {
        presentControllerCalled = true
        lastPresentedController = controller
        lastPresentedControllerAnimated = animated
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

    func updateSettingsButton(state: String) {
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
}
