@testable import HomeAssistant
import UIKit
import WebKit
import XCTest

final class WebViewControllerTests: XCTestCase {
    func testMakeWebViewConfigurationRequiresUserActionForAudioPlayback() {
        let config = WebViewController.makeWebViewConfiguration()

        XCTAssertTrue(config.allowsInlineMediaPlayback)
        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, .audio)
    }

    func testMakeWebViewBottomConstraintPinsWebViewToContainerBottom() {
        let containerView = UIView()
        let webView = WKWebView(frame: .zero, configuration: WebViewController.makeWebViewConfiguration())

        let constraint = WebViewController.makeWebViewBottomConstraint(for: webView, in: containerView)

        XCTAssertIdentical(constraint.firstItem as? WKWebView, webView)
        XCTAssertEqual(constraint.firstAttribute, .bottom)
        XCTAssertEqual(constraint.relation, .equal)
        XCTAssertIdentical(constraint.secondItem as? UIView, containerView)
        XCTAssertEqual(constraint.secondAttribute, .bottom)
    }

    func testUpdateWebViewBottomConstraintUsesKeyboardOverlapHeight() {
        let sut = makeSUT()
        let notification = keyboardNotification(frame: CGRect(x: 0, y: 424, width: 320, height: 216))

        sut.updateWebViewBottomConstraint(using: notification)

        XCTAssertEqual(sut.webViewBottomConstraint?.constant, -216)
    }

    func testScheduleFocusedElementScrollReschedulesExistingWorkItemForVisibleKeyboard() {
        let sut = makeSUT()
        let existingWorkItem = DispatchWorkItem {}
        sut.keyboardFocusedElementScrollWorkItem = existingWorkItem
        let notification = keyboardNotification(frame: CGRect(x: 0, y: 424, width: 320, height: 216), duration: 1)

        sut.scheduleFocusedElementScroll(using: notification)

        XCTAssertTrue(existingWorkItem.isCancelled)
        guard let rescheduledWorkItem = sut.keyboardFocusedElementScrollWorkItem else {
            return XCTFail("Expected a new work item to be scheduled")
        }
        XCTAssertFalse(rescheduledWorkItem === existingWorkItem)
    }

    func testScheduleFocusedElementScrollClearsWorkItemWhenKeyboardIsHidden() {
        let sut = makeSUT()
        let existingWorkItem = DispatchWorkItem {}
        sut.keyboardFocusedElementScrollWorkItem = existingWorkItem
        let notification = keyboardNotification(frame: CGRect(x: 0, y: 640, width: 320, height: 216))

        sut.scheduleFocusedElementScroll(using: notification)

        XCTAssertTrue(existingWorkItem.isCancelled)
        XCTAssertNil(sut.keyboardFocusedElementScrollWorkItem)
    }

    private func makeSUT() -> WebViewController {
        let sut = WebViewController(server: .fake())
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        sut.setValue(containerView, forKey: "view")

        let webView = WKWebView(frame: .zero, configuration: WebViewController.makeWebViewConfiguration())
        webView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(webView)
        let bottomConstraint = WebViewController.makeWebViewBottomConstraint(for: webView, in: containerView)
        sut.webView = webView
        sut.webViewBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bottomConstraint,
        ])

        return sut
    }

    private func keyboardNotification(
        frame: CGRect,
        duration: TimeInterval = 0.25,
        curve: UIView.AnimationCurve = .easeInOut
    ) -> Notification {
        Notification(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [
                UIResponder.keyboardFrameEndUserInfoKey: frame,
                UIResponder.keyboardAnimationDurationUserInfoKey: NSNumber(value: duration),
                UIResponder.keyboardAnimationCurveUserInfoKey: NSNumber(value: curve.rawValue),
            ]
        )
    }
}
