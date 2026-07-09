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

    func testMarkDisconnectedForHardReloadArmsTimer() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        sut.updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)
        XCTAssertEqual(sut.connectionState, .connected)

        sut.markDisconnectedForHardReload()

        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertNotNil(sut.emptyStateTimer)
    }

    func testMarkDisconnectedForHardReloadKeepsAuthInvalid() {
        let sut = makeSUT()
        sut.connectionState = .authInvalid

        sut.markDisconnectedForHardReload()

        XCTAssertEqual(sut.connectionState, .authInvalid)
    }

    func testServerVersionDidChangeClearsFrontendAssetCacheForMatchingServer() {
        let original = Current.websiteDataStoreHandler
        defer { Current.websiteDataStoreHandler = original }
        let handler = FakeWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = handler

        let server = Server.fake()
        let sut = makeSUT(server: server)

        sut.serverVersionDidChange(Notification(
            name: HomeAssistantAPI.serverVersionDidChangeNotification,
            object: server
        ))

        XCTAssertEqual(handler.cleanCacheCallCount, 1)
        XCTAssertEqual(handler.lastDataTypes, WebsiteDataStoreHandlerImpl.frontendAssetDataTypes)
    }

    func testServerVersionDidChangeIgnoresChangesForOtherServers() {
        let original = Current.websiteDataStoreHandler
        defer { Current.websiteDataStoreHandler = original }
        let handler = FakeWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = handler

        let sut = makeSUT(server: .fake())

        sut.serverVersionDidChange(Notification(
            name: HomeAssistantAPI.serverVersionDidChangeNotification,
            object: Server.fake()
        ))

        XCTAssertEqual(handler.cleanCacheCallCount, 0)
    }

    func testServerErrorResponseDecisionShowsEmptyStateForProxyServerErrors() {
        for statusCode in [500, 502, 503, 521, 522, 523, 524] {
            let decision = WebViewController.decisionForMainFrameErrorResponse(
                statusCode: statusCode,
                responseURL: URL(string: "https://example.com/lovelace"),
                initialURL: nil,
                cfMitigated: nil
            )

            XCTAssertEqual(decision, .showEmptyState, "expected empty state for HTTP \(statusCode)")
        }
    }

    func testServerErrorResponseDecisionAllowsClientErrorsToRender() {
        for statusCode in [400, 401, 403, 404, 429] {
            let decision = WebViewController.decisionForMainFrameErrorResponse(
                statusCode: statusCode,
                responseURL: URL(string: "https://example.com/lovelace"),
                initialURL: nil,
                cfMitigated: nil
            )

            XCTAssertEqual(decision, .allow, "expected allow for HTTP \(statusCode)")
        }
    }

    func testServerErrorResponseDecisionAllowsCloudflareChallengeToRender() {
        let decision = WebViewController.decisionForMainFrameErrorResponse(
            statusCode: 503,
            responseURL: URL(string: "https://example.com/lovelace"),
            initialURL: nil,
            cfMitigated: "Challenge"
        )

        XCTAssertEqual(decision, .allow)
    }

    func testServerErrorResponseDecisionReloadsDefaultURLForRestoredPage() {
        let restoredURL = URL(string: "https://example.com/history")!

        for statusCode in [404, 500] {
            let decision = WebViewController.decisionForMainFrameErrorResponse(
                statusCode: statusCode,
                responseURL: restoredURL,
                initialURL: restoredURL,
                cfMitigated: nil
            )

            XCTAssertEqual(decision, .reloadDefaultURL, "expected reload for restored page on HTTP \(statusCode)")
        }
    }

    func testServerErrorLoadErrorCarriesFailingURL() {
        let url = URL(string: "https://example.com/lovelace")!

        let error = WebViewController.serverErrorLoadError(for: url)

        XCTAssertEqual(error.code, .badServerResponse)
        XCTAssertEqual(error.failingURL, url)
    }

    func testHandledServerErrorResponseSuppressesFollowUpProvisionalFailure() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.didHandleServerErrorResponse = true
        sut.latestLoadError = URLError(.badServerResponse)

        sut.webView(WKWebView(), didFailProvisionalNavigation: nil, withError: URLError(.timedOut))

        XCTAssertFalse(sut.didHandleServerErrorResponse)
        XCTAssertEqual((sut.latestLoadError as? URLError)?.code, .badServerResponse)
    }

    private func makeSUT(server: Server = .fake()) -> WebViewController {
        let sut = WebViewController(server: server)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        sut.setValue(containerView, forKey: "view")
        return sut
    }
}

private final class FakeWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    private(set) var cleanCacheCallCount = 0
    private(set) var lastDataTypes: Set<String>?

    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)?) {
        cleanCacheCallCount += 1
        lastDataTypes = dataTypes
    }
}
