//
//  MockWebViewController.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 15/07/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import UIKit
import Shared
@testable import HomeAssistant

final class MockWebViewController: WebViewControllerProtocol {
    var settingsButton: UIButton = UIButton()
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

}
