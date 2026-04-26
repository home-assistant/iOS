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

    func testEmptyStateStyleUsesUnauthenticatedVariantForAuthInvalidConnectionState() {
        let sut = makeSUT()

        let style = sut.emptyStateStyle(for: .authInvalid)

        XCTAssertEqual(style, .unauthenticated)
    }

    func testEmptyStateStyleUsesDisconnectedVariantForDisconnectedConnectionState() {
        let sut = makeSUT()

        let style = sut.emptyStateStyle(for: .disconnected)

        XCTAssertEqual(style, .disconnected)
    }

    func testResetEmptyStateTimerKeepsAuthInvalidConnectionState() {
        let sut = makeSUT()
        sut.connectionState = .authInvalid
        sut.isConnected = false

        sut.resetEmptyStateTimerWithLatestConnectedState()

        XCTAssertEqual(sut.connectionState, .authInvalid)
    }

    func testUpdateFrontendConnectionStateDoesNotDowngradeAuthInvalidToDisconnected() {
        let sut = makeSUT()
        sut.connectionState = .authInvalid

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.disconnected.rawValue)

        XCTAssertEqual(sut.connectionState, .authInvalid)
        XCTAssertNil(sut.emptyStateTimer)
    }

    func testUpdateFrontendConnectionStateSchedulesTimerForDisconnectedState() {
        let sut = makeSUT()

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.disconnected.rawValue)

        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertNotNil(sut.emptyStateTimer)
    }

    func testShowEmptyStateShowsErrorDetailsButtonWhenLatestLoadErrorExists() {
        let sut = makeSUT()
        sut.setupEmptyState()
        sut.connectionState = .disconnected
        sut.latestLoadError = URLError(.notConnectedToInternet)

        sut.showEmptyState()

        XCTAssertEqual(sut.emptyStateView?.style, .disconnected)
        XCTAssertEqual(sut.emptyStateView?.showsErrorDetailsButton, true)
    }

    func testUpdateFrontendConnectionStateClearsLatestLoadError() {
        let sut = makeSUT()
        sut.latestLoadError = URLError(.timedOut)

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)

        XCTAssertNil(sut.latestLoadError)
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
