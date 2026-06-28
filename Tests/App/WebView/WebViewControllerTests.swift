@testable import HomeAssistant
@testable import Shared
import UIKit
import WebKit
import XCTest

@MainActor
final class WebViewControllerTests: XCTestCase {
    func testMakeWebViewConfigurationRequiresUserActionForAudioPlayback() {
        let config = WebViewController.makeWebViewConfiguration()

        XCTAssertTrue(config.allowsInlineMediaPlayback)
        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, .audio)
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

    func testShowEmptyStatePublishesContentWithErrorDetailsButtonWhenLatestLoadErrorExists() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.connectionState = .disconnected
        sut.latestLoadError = URLError(.notConnectedToInternet)

        sut.showEmptyState()

        XCTAssertEqual(overlayState.emptyState?.style, .disconnected)
        XCTAssertEqual(overlayState.emptyState?.showsErrorDetailsButton, true)
    }

    func testHideEmptyStateClearsPublishedContent() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.showEmptyState()
        XCTAssertNotNil(overlayState.emptyState)

        sut.hideEmptyState()

        XCTAssertNil(overlayState.emptyState)
    }

    func testUpdateFrontendConnectionStateClearsLatestLoadError() {
        let sut = makeSUT()
        sut.latestLoadError = URLError(.timedOut)

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)

        XCTAssertNil(sut.latestLoadError)
    }

    func testDisconnectedRetryUsesResetFrontendAction() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        var resetCalled = false
        sut.overlayState = overlayState
        sut.connectionState = .disconnected
        sut.resetFrontendAction = { [weak sut] in
            resetCalled = true
            sut?.overlayState?.emptyState = nil
        }

        sut.showEmptyState()
        overlayState.emptyState?.retryAction()

        XCTAssertTrue(resetCalled)
        XCTAssertNil(overlayState.emptyState)
    }

    func testRestoreConnectedStateAfterSuccessfulFrontendLoadClearsNavigationDisconnect() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        // Mimics didStartProvisionalNavigation forcing disconnected + arming the empty-state timer.
        sut.updateFrontendConnectionState(state: FrontEndConnectionState.disconnected.rawValue)
        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertNotNil(sut.emptyStateTimer)

        sut.restoreConnectedStateAfterSuccessfulFrontendLoad()

        XCTAssertEqual(sut.connectionState, .connected)
        XCTAssertTrue(sut.isConnected)
        XCTAssertNil(sut.emptyStateTimer)
    }

    func testRestoreConnectedStateAfterSuccessfulFrontendLoadKeepsAuthInvalid() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        sut.connectionState = .authInvalid

        sut.restoreConnectedStateAfterSuccessfulFrontendLoad()

        XCTAssertEqual(sut.connectionState, .authInvalid)
    }

    func testRestoreConnectedStateAfterSuccessfulFrontendLoadIgnoresNoActiveURLScreen() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        overlayState.showsNoActiveURL = true
        sut.overlayState = overlayState
        sut.updateFrontendConnectionState(state: FrontEndConnectionState.disconnected.rawValue)

        sut.restoreConnectedStateAfterSuccessfulFrontendLoad()

        XCTAssertEqual(sut.connectionState, .disconnected)
    }

    private func makeSUT() -> WebViewController {
        let sut = WebViewController(server: .fake())
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        sut.setValue(containerView, forKey: "view")
        return sut
    }
}
