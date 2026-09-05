import Alamofire
import GRDB
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

    /// A deliberate log out has to read as "log back in", not as the expired session the same
    /// authentication-less connection state means everywhere else.
    func testEmptyStateStyleUsesLoggedOutVariantAfterLogOut() {
        let sut = makeSUT()
        sut.didLogOut = true

        XCTAssertEqual(sut.emptyStateStyle(for: .authInvalid), .loggedOut)
        XCTAssertEqual(sut.emptyStateStyle(for: .disconnected), .loggedOut)
    }

    /// Logging out keeps the server registered, so the way back in is the empty state asking for a
    /// log in rather than the app switching to another server or dropping this one.
    func testShowLoggedOutStateKeepsServerAndPublishesLoggedOutEmptyState() {
        let server = Server.fake()
        let sut = makeSUT(server: server)
        // Entering the logged-out state parks the web view on a blank page, so it needs a real one.
        sut.webView = WKWebView(frame: .zero)
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.showLoggedOutState()

        XCTAssertTrue(sut.didLogOut)
        XCTAssertEqual(sut.connectionState, .authInvalid)
        XCTAssertEqual(overlayState.connectionState, .authInvalid)
        XCTAssertEqual(overlayState.emptyState?.style, .loggedOut)
        XCTAssertEqual(overlayState.emptyState?.server.identifier, server.identifier)
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

    /// Going back to a page WebKit kept in its page cache restarts the stand-by loader, but the restored
    /// frontend already fired its one and only `frontend/loaded` and never fires it again, so the restore
    /// itself has to report the frontend as loaded or the loader covers a working page forever.
    func testFrontendRestoredFromPageCacheReportsLoaded() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.connectionState = .connected
        overlayState.connectionState = .unknown

        sut.handleFrontendRestoredFromPageCache()

        XCTAssertEqual(sut.connectionState, .loaded)
        XCTAssertEqual(overlayState.connectionState, .loaded)
    }

    /// `connectionState` belongs to the page the user navigated away to, not to the restored one, so a
    /// connection lost while they were elsewhere must not suppress the restore.
    func testFrontendRestoredFromPageCacheReportsLoadedEvenAfterTheInterimPageDisconnected() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.connectionState = .disconnected
        overlayState.connectionState = .unknown

        sut.handleFrontendRestoredFromPageCache()

        XCTAssertEqual(sut.connectionState, .loaded)
        XCTAssertEqual(overlayState.connectionState, .loaded)
    }

    /// Credentials the server rejected stay rejected across a restore, so the re-authentication empty
    /// state has to survive it.
    func testFrontendRestoredFromPageCacheIsIgnoredWhileAuthenticationIsInvalid() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.connectionState = .authInvalid
        overlayState.connectionState = .unknown

        sut.handleFrontendRestoredFromPageCache()

        XCTAssertEqual(sut.connectionState, .authInvalid)
        XCTAssertEqual(overlayState.connectionState, .unknown)
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

    func testExternalAuthFailureMarksDisconnectedAndArmsEmptyStateTimer() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.handleExternalAuthFailure(error: URLError(.notConnectedToInternet))

        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertEqual(overlayState.connectionState, .disconnected)
        XCTAssertEqual((sut.latestLoadError as? URLError)?.code, .notConnectedToInternet)
        XCTAssertNotNil(sut.emptyStateTimer)
    }

    func testExternalAuthFailureUnwrapsSessionTaskErrorForTheDetailsScreen() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()

        sut.handleExternalAuthFailure(
            error: AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet))
        )

        XCTAssertEqual((sut.latestLoadError as? URLError)?.code, .notConnectedToInternet)
    }

    func testExternalAuthFailureIsIgnoredWhileFrontendIsDisplayed() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        sut.connectionState = .loaded

        sut.handleExternalAuthFailure(error: URLError(.notConnectedToInternet))

        XCTAssertEqual(sut.connectionState, .loaded)
        XCTAssertNil(sut.latestLoadError)
        XCTAssertNil(sut.emptyStateTimer)
    }

    func testExternalAuthFailureKeepsAuthInvalid() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        sut.connectionState = .authInvalid

        sut.handleExternalAuthFailure(error: URLError(.notConnectedToInternet))

        XCTAssertEqual(sut.connectionState, .authInvalid)
    }

    func testRepeatedExternalAuthFailuresDoNotPushBackTheEmptyState() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.handleExternalAuthFailure(error: URLError(.notConnectedToInternet))
        let armedTimer = sut.emptyStateTimer

        sut.handleExternalAuthFailure(error: URLError(.timedOut))

        XCTAssertTrue(armedTimer === sut.emptyStateTimer)
        XCTAssertEqual((sut.latestLoadError as? URLError)?.code, .timedOut)
    }

    func testExternalAuthFailureDoesNotReArmWhileEmptyStateIsShown() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.connectionState = .disconnected
        sut.showEmptyState()
        XCTAssertNotNil(overlayState.emptyState)

        sut.handleExternalAuthFailure(error: URLError(.notConnectedToInternet))

        XCTAssertNil(sut.emptyStateTimer)
    }

    func testUpdateFrontendConnectionStateClearsLatestLoadError() {
        let sut = makeSUT()
        sut.latestLoadError = URLError(.timedOut)

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)

        XCTAssertNil(sut.latestLoadError)
    }

    func testDisconnectedRetryClearsFrontendCacheThenUsesResetFrontendAction() {
        let original = Current.websiteDataStoreHandler
        defer { Current.websiteDataStoreHandler = original }
        let handler = FakeWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = handler

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

        XCTAssertEqual(handler.cleanCacheCallCount, 1)
        XCTAssertEqual(handler.lastDataTypes, WebsiteDataStoreHandlerImpl.frontendAssetDataTypes)
        XCTAssertFalse(resetCalled, "retry must wait for cache clearing to finish before resetting")

        handler.invokePendingCompletion()

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

    func testFrontendAssetCacheCleanDecisionCleansWhenNeverCleaned() {
        XCTAssertTrue(WebsiteDataStoreHandlerImpl.shouldCleanFrontendAssetCache(
            lastCleanDate: nil,
            now: Date(timeIntervalSince1970: 100)
        ))
    }

    func testFrontendAssetCacheCleanDecisionSkipsWhenRecentlyCleaned() {
        let now = Date(timeIntervalSince1970: 1000)

        XCTAssertFalse(WebsiteDataStoreHandlerImpl.shouldCleanFrontendAssetCache(
            lastCleanDate: now.addingTimeInterval(-WebsiteDataStoreHandlerImpl.frontendAssetCacheCleanInterval),
            now: now
        ))
    }

    func testFrontendAssetCacheCleanDecisionCleansWhenOlderThanThreeDays() {
        let now = Date(timeIntervalSince1970: 1000)

        XCTAssertTrue(WebsiteDataStoreHandlerImpl.shouldCleanFrontendAssetCache(
            lastCleanDate: now.addingTimeInterval(-WebsiteDataStoreHandlerImpl.frontendAssetCacheCleanInterval - 1),
            now: now
        ))
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

    func testServerErrorResponseDecisionReloadsDefaultURLForRestoredPage() throws {
        let restoredURL = try XCTUnwrap(URL(string: "https://example.com/history"))

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

    func testServerErrorLoadErrorCarriesFailingURL() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/lovelace"))

        let error = WebViewController.serverErrorLoadError(for: url)

        XCTAssertEqual(error.code, .badServerResponse)
        XCTAssertEqual(error.failingURL, url)
    }

    func testInterceptedServerErrorMarksDisconnectedFromReadyOrUnknownStates() {
        for current in [FrontEndConnectionState.connected, .loaded, .disconnected, .unknown] {
            let resolved = WebViewController.connectionStateForInterceptedServerError(current: current)

            XCTAssertEqual(resolved, .disconnected, "expected disconnected when current is \(current)")
        }
    }

    func testInterceptedServerErrorPreservesAuthInvalid() {
        let resolved = WebViewController.connectionStateForInterceptedServerError(current: .authInvalid)

        XCTAssertEqual(resolved, .authInvalid)
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

    func testShowReAuthPopupMarksAuthInvalidAndShowsReauthEmptyState() {
        let server = Server.fake()
        let sut = makeSUT(server: server)
        sut.webView = WKWebView(frame: .zero)
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.showReAuthPopup(serverId: server.identifier.rawValue, code: 401)

        XCTAssertEqual(sut.connectionState, .authInvalid)
        XCTAssertEqual(overlayState.connectionState, .authInvalid)
        XCTAssertEqual(overlayState.emptyState?.style, .unauthenticated)
    }

    func testShowReAuthPopupIgnoresEventsForOtherServers() {
        let sut = makeSUT(server: .fake())
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.showReAuthPopup(serverId: Server.fake().identifier.rawValue, code: 401)

        XCTAssertEqual(sut.connectionState, .unknown)
        XCTAssertNil(overlayState.emptyState)
    }

    func testUnauthenticatedOnboardingStateShowsReauthEmptyState() async {
        let server = Server.fake()
        let sut = makeSUT(server: server)
        sut.webView = WKWebView(frame: .zero)
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.onboardingStateDidChange(to: .needed(.unauthenticated(server.identifier.rawValue, 401)))

        await waitUntil { sut.connectionState == .authInvalid }
        XCTAssertEqual(overlayState.emptyState?.style, .unauthenticated)
    }

    // MARK: - Client certificate (mTLS)

    /// A certificate problem is a dead end for retries and re-authentication alike, so it wins over the
    /// connection state; only a deliberate log out still reads as "log back in".
    func testEmptyStateStyleUsesClientCertificateVariantsWhenAnIssueIsRecorded() {
        let sut = makeSUT()

        sut.clientCertificateIssue = .required
        XCTAssertEqual(sut.emptyStateStyle(for: .disconnected), .clientCertificateRequired)
        XCTAssertEqual(sut.emptyStateStyle(for: .authInvalid), .clientCertificateRequired)

        sut.clientCertificateIssue = .rejected
        XCTAssertEqual(sut.emptyStateStyle(for: .disconnected), .clientCertificateRejected)

        sut.didLogOut = true
        XCTAssertEqual(sut.emptyStateStyle(for: .disconnected), .loggedOut)
    }

    func testClientCertificateIssueDependsOnWhetherTheDeviceHasACertificate() {
        for code in [URLError.Code.clientCertificateRequired, .clientCertificateRejected] {
            XCTAssertEqual(
                WebViewController.clientCertificateIssue(
                    for: URLError(code),
                    receivedClientCertificateChallenge: false,
                    hasClientCertificate: false
                ),
                .required,
                "expected a missing certificate to be required for \(code)"
            )
            XCTAssertEqual(
                WebViewController.clientCertificateIssue(
                    for: URLError(code),
                    receivedClientCertificateChallenge: false,
                    hasClientCertificate: true
                ),
                .rejected,
                "expected a configured certificate to be rejected for \(code)"
            )
        }
    }

    /// A dropped handshake or a cancelled challenge is only a certificate problem when the server actually
    /// asked for a certificate on this navigation; otherwise it stays the connectivity failure it looks like.
    func testClientCertificateIssueForHandshakeFailuresRequiresAChallenge() {
        for code in [URLError.Code.secureConnectionFailed, .userCancelledAuthentication] {
            XCTAssertEqual(
                WebViewController.clientCertificateIssue(
                    for: URLError(code),
                    receivedClientCertificateChallenge: true,
                    hasClientCertificate: true
                ),
                .rejected
            )
            XCTAssertNil(WebViewController.clientCertificateIssue(
                for: URLError(code),
                receivedClientCertificateChallenge: false,
                hasClientCertificate: true
            ))
        }
    }

    /// WebKit hands failures over as plain `Error`s; one carried as an `NSError` in `NSURLErrorDomain`
    /// has to classify exactly like its `URLError` counterpart.
    func testClientCertificateIssueClassifiesNSURLErrorDomainErrors() {
        let error = NSError(domain: NSURLErrorDomain, code: URLError.Code.clientCertificateRequired.rawValue)

        XCTAssertEqual(
            WebViewController.clientCertificateIssue(
                for: error,
                receivedClientCertificateChallenge: false,
                hasClientCertificate: false
            ),
            .required
        )
        XCTAssertNil(WebViewController.clientCertificateIssue(
            for: NSError(domain: NSCocoaErrorDomain, code: URLError.Code.clientCertificateRequired.rawValue),
            receivedClientCertificateChallenge: true,
            hasClientCertificate: false
        ))
    }

    func testClientCertificateIssueIgnoresUnrelatedErrors() {
        XCTAssertNil(WebViewController.clientCertificateIssue(
            for: URLError(.timedOut),
            receivedClientCertificateChallenge: true,
            hasClientCertificate: true
        ))
        XCTAssertNil(WebViewController.clientCertificateIssue(
            for: NSError(domain: "Test", code: 1),
            receivedClientCertificateChallenge: true,
            hasClientCertificate: false
        ))
    }

    func testClientCertificateRefusalNeedsA400AndAChallenge() {
        XCTAssertTrue(WebViewController.isClientCertificateRefusal(
            statusCode: 400,
            receivedClientCertificateChallenge: true
        ))
        XCTAssertFalse(WebViewController.isClientCertificateRefusal(
            statusCode: 400,
            receivedClientCertificateChallenge: false
        ))
        XCTAssertFalse(WebViewController.isClientCertificateRefusal(
            statusCode: 403,
            receivedClientCertificateChallenge: true
        ))
    }

    func testProvisionalNavigationFailureOverClientCertificateShowsCertificateEmptyState() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.webView(WKWebView(), didFailProvisionalNavigation: nil, withError: URLError(.clientCertificateRequired))

        XCTAssertEqual(sut.clientCertificateIssue, .required)
        XCTAssertEqual(overlayState.emptyState?.style, .clientCertificateRequired)
    }

    func testProvisionalNavigationFailureWithAConfiguredCertificateShowsRejectedEmptyState() {
        let sut = makeSUT(server: .fake(update: { info in
            info.connection.clientCertificate = ClientCertificate(keychainIdentifier: "id", displayName: "Test")
        }))
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.webView(WKWebView(), didFailProvisionalNavigation: nil, withError: URLError(.clientCertificateRejected))

        XCTAssertEqual(sut.clientCertificateIssue, .rejected)
        XCTAssertEqual(overlayState.emptyState?.style, .clientCertificateRejected)
    }

    func testProvisionalNavigationFailureWithoutCertificateProblemKeepsDisconnectedEmptyState() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.webView(WKWebView(), didFailProvisionalNavigation: nil, withError: URLError(.timedOut))

        XCTAssertNil(sut.clientCertificateIssue)
        XCTAssertEqual(overlayState.emptyState?.style, .disconnected)
    }

    /// The token request goes through the app's own session, so the certificate problem there only
    /// shows in the error code.
    func testExternalAuthFailureOverClientCertificateRecordsIssue() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()

        sut.handleExternalAuthFailure(error: URLError(.clientCertificateRequired))

        XCTAssertEqual(sut.clientCertificateIssue, .required)
        XCTAssertNotNil(sut.emptyStateTimer)
    }

    func testExternalAuthFailureOverClientCertificateSwapsAnEmptyStateAlreadyShowing() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.connectionState = .disconnected
        sut.showEmptyState()
        XCTAssertEqual(overlayState.emptyState?.style, .disconnected)

        sut.handleExternalAuthFailure(error: URLError(.clientCertificateRequired))

        XCTAssertEqual(overlayState.emptyState?.style, .clientCertificateRequired)
    }

    func testHideEmptyStateClearsClientCertificateIssue() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        sut.clientCertificateIssue = .rejected

        sut.hideEmptyState()

        XCTAssertNil(sut.clientCertificateIssue)
    }

    func testFinishedNavigationClearsClientCertificateIssue() {
        let sut = makeSUT()
        // Finishing a navigation applies the web view settings, so it needs a real web view.
        sut.webView = WKWebView(frame: .zero)
        sut.overlayState = WebFrontendOverlayState()
        sut.clientCertificateIssue = .required

        sut.webView(WKWebView(), didFinish: nil)

        XCTAssertNil(sut.clientCertificateIssue)
    }

    func testClientCertificateChallengeIsRememberedUntilTheNextNavigationStarts() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        var disposition: URLSession.AuthChallengeDisposition?

        sut.webView(WKWebView(), didReceive: clientCertificateChallenge()) { result, _ in
            disposition = result
        }

        XCTAssertTrue(sut.didReceiveClientCertificateChallenge)
        // Without a certificate the challenge is left to the default handling, which is what fails later.
        XCTAssertEqual(disposition, .performDefaultHandling)

        sut.webView(WKWebView(), didStartProvisionalNavigation: nil)

        XCTAssertFalse(sut.didReceiveClientCertificateChallenge)
    }

    func testFailedNavigationOverClientCertificateShowsCertificateEmptyState() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.webView(WKWebView(), didFail: nil, withError: URLError(.clientCertificateRequired))

        XCTAssertEqual(sut.clientCertificateIssue, .required)
        XCTAssertEqual(overlayState.emptyState?.style, .clientCertificateRequired)
    }

    /// nginx answers 400 instead of failing the handshake, so the refusal has to be taken over from
    /// the response: cancel the page and show the certificate empty state in its place.
    func testClientCertificateRefusalCancelsTheNavigationAndShowsCertificateEmptyState() throws {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.didReceiveClientCertificateChallenge = true
        let url = try XCTUnwrap(URL(string: "https://example.com/lovelace"))
        var decision: WKNavigationResponsePolicy?

        let handled = sut.handleClientCertificateRefusalIfNeeded(statusCode: 400, responseURL: url) {
            decision = $0
        }

        XCTAssertTrue(handled)
        XCTAssertEqual(decision, .cancel)
        XCTAssertTrue(sut.didHandleServerErrorResponse)
        XCTAssertEqual(sut.clientCertificateIssue, .required)
        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertEqual((sut.latestLoadError as? URLError)?.failingURL, url)
        XCTAssertEqual(overlayState.emptyState?.style, .clientCertificateRequired)
    }

    /// A connection that already failed over the certificate is reused without a new handshake, so a
    /// known problem stands in for the challenge the reused connection never repeats.
    func testClientCertificateRefusalIsRecognisedFromAKnownIssueWithoutANewChallenge() {
        let sut = makeSUT(server: .fake(update: { info in
            info.connection.clientCertificate = ClientCertificate(keychainIdentifier: "id", displayName: "Test")
        }))
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.clientCertificateIssue = .rejected

        let handled = sut.handleClientCertificateRefusalIfNeeded(statusCode: 400, responseURL: nil) { _ in }

        XCTAssertTrue(handled)
        XCTAssertEqual(overlayState.emptyState?.style, .clientCertificateRejected)
    }

    func testErrorResponsesThatAreNotCertificateRefusalsAreLeftToTheRegularHandling() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        var decisions = [WKNavigationResponsePolicy]()

        // A 400 without a challenge is the frontend's own answer, not the proxy's.
        XCTAssertFalse(sut.handleClientCertificateRefusalIfNeeded(statusCode: 400, responseURL: nil) {
            decisions.append($0)
        })
        sut.didReceiveClientCertificateChallenge = true
        XCTAssertFalse(sut.handleClientCertificateRefusalIfNeeded(statusCode: 503, responseURL: nil) {
            decisions.append($0)
        })

        XCTAssertTrue(decisions.isEmpty)
        XCTAssertNil(sut.clientCertificateIssue)
        XCTAssertNil(sut.overlayState?.emptyState)
    }

    func testMainFrameCertificateRefusalResponseIsReplacedByTheCertificateEmptyState() throws {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.didReceiveClientCertificateChallenge = true
        var decision: WKNavigationResponsePolicy?

        try sut.webView(WKWebView(), decidePolicyFor: FakeNavigationResponse(statusCode: 400)) { decision = $0 }

        XCTAssertEqual(decision, .cancel)
        XCTAssertTrue(sut.lastNavigationWasServerError)
        XCTAssertEqual(overlayState.emptyState?.style, .clientCertificateRequired)
    }

    /// The frontend's own 400s keep rendering as pages; only a refusal behind a certificate challenge is
    /// taken over.
    func testMainFrameClientErrorResponseWithoutAChallengeStillRenders() throws {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        var decision: WKNavigationResponsePolicy?

        try sut.webView(WKWebView(), decidePolicyFor: FakeNavigationResponse(statusCode: 400)) { decision = $0 }

        XCTAssertEqual(decision, .allow)
        XCTAssertNil(sut.clientCertificateIssue)
        XCTAssertNil(sut.overlayState?.emptyState)
    }

    func testPresentClientCertificateImportPresentsTheImportSheet() async {
        let sut = makeSUT()
        // Attaching to a window changes traits, which the controller forwards to its web view.
        sut.webView = WKWebView(frame: .zero)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = sut
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        sut.presentClientCertificateImport()

        await waitUntil { sut.presentedViewController != nil }
        XCTAssertEqual(sut.presentedViewController?.modalPresentationStyle, .formSheet)
        sut.presentedViewController?.dismiss(animated: false)
    }

    func testImportedClientCertificateIsStoredAndTheFrontendReloads() {
        let server = Server.fake()
        let sut = makeSUT(server: server)
        // Reloading goes through the web view, so it needs a real one.
        sut.webView = WKWebView(frame: .zero)
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.clientCertificateIssue = .required
        sut.connectionState = .disconnected
        sut.showEmptyState()
        XCTAssertEqual(overlayState.emptyState?.style, .clientCertificateRequired)
        let certificate = ClientCertificate(keychainIdentifier: "id", displayName: "Test")

        sut.makeClientCertificateImportView().onImport(certificate)

        XCTAssertEqual(server.info.connection.clientCertificate, certificate)
        XCTAssertNil(sut.clientCertificateIssue)
        XCTAssertEqual(sut.connectionState, .unknown)
        XCTAssertEqual(overlayState.connectionState, .unknown)
        XCTAssertNil(overlayState.emptyState)
    }

    func testCancellingClientCertificateImportKeepsTheEmptyState() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.clientCertificateIssue = .required
        sut.connectionState = .disconnected
        sut.showEmptyState()

        sut.makeClientCertificateImportView().onCancel()

        XCTAssertEqual(sut.clientCertificateIssue, .required)
        XCTAssertEqual(overlayState.emptyState?.style, .clientCertificateRequired)
    }

    private func clientCertificateChallenge() -> URLAuthenticationChallenge {
        URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpace(
                host: "example.com",
                port: 443,
                protocol: "https",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodClientCertificate
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: FakeChallengeSender()
        )
    }

    func testRestoredURLRebuildsSavedPathOntoLiveBaseIgnoringSavedHost() throws {
        // A path saved on the internal base is restored against whatever base is active now (e.g. remote
        // UI), so only path/query/fragment carry over -- never the host.
        let restored = try WebViewController.restoredURL(
            base: XCTUnwrap(URL(string: "https://remote.example.com:8123")),
            relativePath: "/lovelace/kitchen"
        )

        XCTAssertEqual(restored, URL(string: "https://remote.example.com:8123/lovelace/kitchen"))
    }

    func testRestoredURLPreservesQueryAndFragment() throws {
        let restored = try WebViewController.restoredURL(
            base: XCTUnwrap(URL(string: "http://homeassistant.local:8123")),
            relativePath: "/history?back=1#anchor"
        )

        XCTAssertEqual(restored, URL(string: "http://homeassistant.local:8123/history?back=1#anchor"))
    }

    func testRestoredURLHandlesRootPath() throws {
        let restored = try WebViewController.restoredURL(
            base: XCTUnwrap(URL(string: "http://homeassistant.local:8123")),
            relativePath: "/"
        )

        XCTAssertEqual(restored, URL(string: "http://homeassistant.local:8123/"))
    }

    /// SwiftUI defers status-bar appearance to the embedded controller, so the UIKit override must
    /// resolve the kiosk hide-status-bar and full-screen settings itself.
    func testPrefersStatusBarHiddenTracksKioskAndFullScreenSettings() throws {
        let previousDatabase = Current.database
        let previousKiosk = Current.kiosk
        let previousFullScreen = Current.settingsStore.fullScreen
        defer {
            Current.database = previousDatabase
            Current.kiosk = previousKiosk
            Current.settingsStore.fullScreen = previousFullScreen
        }

        let database = try DatabaseQueue()
        try KioskSettingsTable().createIfNeeded(database: database)
        Current.database = { database }
        Current.settingsStore.fullScreen = false

        func setKiosk(enabled: Bool, hideStatusBar: Bool) throws {
            try database.write { db in
                try KioskSettings(enabled: enabled, hideStatusBar: hideStatusBar).insert(db, onConflict: .replace)
            }
            Current.kiosk = KioskModeManager()
        }

        let sut = makeSUT()

        try setKiosk(enabled: true, hideStatusBar: true)
        XCTAssertTrue(sut.prefersStatusBarHidden)

        try setKiosk(enabled: true, hideStatusBar: false)
        XCTAssertFalse(sut.prefersStatusBarHidden)

        try setKiosk(enabled: false, hideStatusBar: true)
        XCTAssertFalse(sut.prefersStatusBarHidden)

        Current.settingsStore.fullScreen = true
        XCTAssertTrue(sut.prefersStatusBarHidden)
    }

    private func makeSUT(server: Server = .fake()) -> WebViewController {
        let sut = WebViewController(server: server)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        sut.setValue(containerView, forKey: "view")
        return sut
    }

    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 2,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "condition not met within \(timeout)s", file: file, line: line)
    }
}

/// A main-frame navigation response with the given status, for the response-policy delegate.
private final class FakeNavigationResponse: WKNavigationResponse {
    private let fakeResponse: HTTPURLResponse

    init(statusCode: Int) throws {
        self.fakeResponse = try XCTUnwrap(HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://example.com/lovelace")),
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ))
        super.init()
        // Kept alive for the rest of the run: WebKit's `dealloc` retains the API object that only its
        // own initialisers create, so releasing a plainly initialised instance crashes.
        _ = Unmanaged.passRetained(self)
    }

    override var isForMainFrame: Bool { true }
    override var response: URLResponse { fakeResponse }
}

private final class FakeChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}

private final class FakeWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    private(set) var cleanCacheCallCount = 0
    private(set) var cleanFrontendAssetCacheIfNeededCallCount = 0
    private(set) var lastDataTypes: Set<String>?
    var completesFrontendAssetCacheCleanImmediately = true
    var frontendAssetCacheCleanResult = false
    private var pendingCompletion: (() -> Void)?
    private var pendingFrontendAssetCacheCompletion: ((Bool) -> Void)?

    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)?) {
        cleanCacheCallCount += 1
        lastDataTypes = dataTypes
        pendingCompletion = completion
    }

    func cleanFrontendAssetCacheIfNeeded(completion: ((Bool) -> Void)?) {
        cleanFrontendAssetCacheIfNeededCallCount += 1
        pendingFrontendAssetCacheCompletion = completion
        if completesFrontendAssetCacheCleanImmediately {
            invokePendingFrontendAssetCacheCompletion(didClean: frontendAssetCacheCleanResult)
        }
    }

    func invokePendingCompletion() {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?()
    }

    func invokePendingFrontendAssetCacheCompletion(didClean: Bool) {
        let completion = pendingFrontendAssetCacheCompletion
        pendingFrontendAssetCacheCompletion = nil
        completion?(didClean)
    }
}

@MainActor
final class WebViewControllerURLLoadingTests: XCTestCase {
    private var previousRefreshNetworkInformation: (() async -> Void)!
    private var previousWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol!
    private var websiteDataStoreHandler: FakeWebsiteDataStoreHandler!

    override func setUp() {
        super.setUp()
        previousRefreshNetworkInformation = Current.connectivity.refreshNetworkInformation
        previousWebsiteDataStoreHandler = Current.websiteDataStoreHandler
        websiteDataStoreHandler = FakeWebsiteDataStoreHandler()
        Current.connectivity.refreshNetworkInformation = {}
        Current.websiteDataStoreHandler = websiteDataStoreHandler
    }

    override func tearDown() {
        Current.connectivity.refreshNetworkInformation = previousRefreshNetworkInformation
        Current.websiteDataStoreHandler = previousWebsiteDataStoreHandler
        websiteDataStoreHandler = nil
        super.tearDown()
    }

    func testLoadActiveURLSkipsWhileRecentAttemptIsInFlight() {
        let sut = makeSUT()
        let inFlight = neverFinishingTask()
        sut.loadActiveURLTask = inFlight
        sut.loadActiveURLTaskStartDate = Current.date()

        sut.loadActiveURLIfNeeded()

        XCTAssertEqual(sut.loadActiveURLTask, inFlight)
        XCTAssertFalse(inFlight.isCancelled)
        inFlight.cancel()
    }

    func testLoadActiveURLCancelsAndReplacesStaleAttempt() async {
        let sut = makeSUT()
        let stale = neverFinishingTask()
        sut.loadActiveURLTask = stale
        sut.loadActiveURLTaskStartDate = Current.date()
            .addingTimeInterval(-WebViewController.loadActiveURLStaleInterval)

        sut.loadActiveURLIfNeeded()

        XCTAssertTrue(stale.isCancelled)
        XCTAssertNotNil(sut.loadActiveURLTask)
        XCTAssertNotEqual(sut.loadActiveURLTask, stale)

        await sut.loadActiveURLTask?.value
        XCTAssertNil(sut.loadActiveURLTask)
    }

    func testLoadActiveURLDoesNothingWhileAppIsInBackground() {
        let sut = makeSUT()
        sut.isAppInBackground = { true }

        sut.loadActiveURLIfNeeded()

        XCTAssertEqual(websiteDataStoreHandler.cleanFrontendAssetCacheIfNeededCallCount, 0)
        XCTAssertNil(sut.loadActiveURLTask)
        XCTAssertNil(sut.loadActiveURLTaskStartDate)
    }

    /// The blank page behind the logged-out empty state reads as the wrong URL, so without this the
    /// next trigger — a settings sheet closing, the app coming back to the foreground, the token
    /// update the log out itself writes — would navigate back into the server the user just left.
    func testLoadActiveURLDoesNothingAfterLogOut() {
        let sut = makeSUT()
        sut.didLogOut = true

        sut.loadActiveURLIfNeeded()

        XCTAssertEqual(websiteDataStoreHandler.cleanFrontendAssetCacheIfNeededCallCount, 0)
        XCTAssertNil(sut.loadActiveURLTask)
        XCTAssertNil(sut.loadActiveURLTaskStartDate)
    }

    /// The cache-clean check is asynchronous, so a log out can land between the two halves of an
    /// attempt that already passed the guard on the way in.
    func testLoadActiveURLDoesNothingWhenLogOutLandsDuringCacheCleanCheck() {
        let sut = makeSUT()
        websiteDataStoreHandler.completesFrontendAssetCacheCleanImmediately = false
        sut.loadActiveURLIfNeeded()

        sut.didLogOut = true
        websiteDataStoreHandler.invokePendingFrontendAssetCacheCompletion(didClean: true)

        XCTAssertNil(sut.loadActiveURLTask)
        XCTAssertNil(sut.loadActiveURLTaskStartDate)
    }

    func testShowLoggedOutStateCancelsInFlightActiveURLAttempt() {
        let sut = makeSUT()
        let inFlight = neverFinishingTask()
        sut.loadActiveURLTask = inFlight
        sut.loadActiveURLTaskStartDate = Current.date()

        sut.showLoggedOutState()

        XCTAssertTrue(inFlight.isCancelled)
        XCTAssertNil(sut.loadActiveURLTask)
        XCTAssertNil(sut.loadActiveURLTaskStartDate)
    }

    func testLoadActiveURLResumesOnceLoggedBackIn() {
        let sut = makeSUT()
        sut.didLogOut = true
        sut.loadActiveURLIfNeeded()

        sut.didLogOut = false
        sut.loadActiveURLIfNeeded()

        XCTAssertEqual(websiteDataStoreHandler.cleanFrontendAssetCacheIfNeededCallCount, 1)
        XCTAssertNotNil(sut.loadActiveURLTask)
        sut.loadActiveURLTask?.cancel()
    }

    func testLoadActiveURLWaitsForFrontendAssetCacheCleanCheckBeforeLoading() async {
        let sut = makeSUT()
        websiteDataStoreHandler.completesFrontendAssetCacheCleanImmediately = false

        sut.loadActiveURLIfNeeded()

        XCTAssertEqual(websiteDataStoreHandler.cleanFrontendAssetCacheIfNeededCallCount, 1)
        XCTAssertNil(sut.loadActiveURLTask)

        websiteDataStoreHandler.invokePendingFrontendAssetCacheCompletion(didClean: true)

        XCTAssertNotNil(sut.loadActiveURLTask)
        await sut.loadActiveURLTask?.value
    }

    func testLoadActiveURLRechecksBackgroundStateAfterFrontendAssetCacheCleanCheck() {
        var isAppInBackground = false
        let sut = makeSUT()
        sut.isAppInBackground = { isAppInBackground }
        websiteDataStoreHandler.completesFrontendAssetCacheCleanImmediately = false

        sut.loadActiveURLIfNeeded()
        isAppInBackground = true
        websiteDataStoreHandler.invokePendingFrontendAssetCacheCompletion(didClean: false)

        XCTAssertNil(sut.loadActiveURLTask)
        XCTAssertNil(sut.loadActiveURLTaskStartDate)
    }

    func testLoadActiveURLRequestsNavigationAndClearsInFlightState() async {
        let sut = makeSUT()

        sut.loadActiveURLIfNeeded()
        XCTAssertNotNil(sut.loadActiveURLTask)
        await sut.loadActiveURLTask?.value

        XCTAssertNil(sut.loadActiveURLTask)
        XCTAssertNil(sut.loadActiveURLTaskStartDate)
        // Server.fake()'s active URL; set when the provisional navigation starts.
        await waitUntil { sut.webView.url != nil }
        XCTAssertEqual(sut.webView.url?.host, "homeassistant.local")
    }

    func testLoadActiveURLShowsNoActiveURLOverlayWhenNoURLIsAvailable() async {
        let sut = makeSUT(server: .fake(update: { info in
            info.connection.set(address: nil, for: .external)
            // Re-evaluate now so the load attempt doesn't change the stored active URL type,
            // which would fire the server observer and enqueue a stray load into later tests.
            _ = info.connection.evaluateActiveURL()
        }))
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.loadActiveURLIfNeeded()
        await sut.loadActiveURLTask?.value

        XCTAssertTrue(overlayState.showsNoActiveURL)
        XCTAssertNil(sut.loadActiveURLTask)
    }

    /// When an attempt hung and the web view is still blank, the last-known URL must load
    /// synchronously -- without waiting for any async work, which just hung once already.
    func testStaleAttemptTriggersImmediateFallbackLoadFromLastKnownState() async {
        let gate = AsyncGate()
        Current.connectivity.refreshNetworkInformation = { await gate.holdIfNeeded() }
        let sut = makeSUT()

        gate.shouldHold = true
        sut.loadActiveURLIfNeeded()
        let hungAttempt = sut.loadActiveURLTask
        await waitUntil { gate.waiterCount == 1 }
        sut.loadActiveURLTaskStartDate = Current.date()
            .addingTimeInterval(-WebViewController.loadActiveURLStaleInterval)

        sut.loadActiveURLIfNeeded()

        // The replacement attempt is itself parked at the gate, so only the synchronous
        // fallback can have loaded anything.
        await waitUntil { sut.webView.url != nil }
        XCTAssertEqual(sut.webView.url?.host, "homeassistant.local")

        await waitUntil { gate.waiterCount == 2 }
        gate.releaseNext()
        gate.releaseNext()
        await hungAttempt?.value
        await sut.loadActiveURLTask?.value
        XCTAssertNil(sut.loadActiveURLTask)
    }

    /// Regression test for the stuck blank web view: an attempt that hung, was declared stale, and
    /// was replaced must not clear (or otherwise affect) the attempt that replaced it when it
    /// eventually resumes.
    func testCancelledStaleAttemptDoesNotClearItsReplacement() async {
        let gate = AsyncGate()
        Current.connectivity.refreshNetworkInformation = { await gate.holdIfNeeded() }
        let sut = makeSUT()

        // First attempt hangs refreshing network information.
        gate.shouldHold = true
        sut.loadActiveURLIfNeeded()
        let hungAttempt = sut.loadActiveURLTask
        XCTAssertNotNil(hungAttempt)
        await waitUntil { gate.waiterCount == 1 }

        // Once stale, a new call cancels it and the replacement completes normally.
        sut.loadActiveURLTaskStartDate = Current.date()
            .addingTimeInterval(-WebViewController.loadActiveURLStaleInterval)
        gate.shouldHold = false
        sut.loadActiveURLIfNeeded()
        XCTAssertEqual(hungAttempt?.isCancelled, true)
        await sut.loadActiveURLTask?.value
        XCTAssertNil(sut.loadActiveURLTask)

        // A third attempt is in flight when the hung attempt finally wakes up.
        gate.shouldHold = true
        sut.loadActiveURLIfNeeded()
        let inFlightAttempt = sut.loadActiveURLTask
        XCTAssertNotNil(inFlightAttempt)
        await waitUntil { gate.waiterCount == 2 }

        gate.releaseNext() // resumes only the hung (cancelled) attempt
        await hungAttempt?.value

        XCTAssertEqual(sut.loadActiveURLTask, inFlightAttempt)

        gate.releaseNext()
        await inFlightAttempt?.value
        XCTAssertNil(sut.loadActiveURLTask)
    }

    private func makeSUT(server: Server = .fake()) -> WebViewController {
        let sut = WebViewController(server: server)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        // KVC-setting the view bypasses loadView/viewDidLoad, so the webView the URL-loading
        // paths dereference must be provided explicitly.
        sut.setValue(containerView, forKey: "view")
        sut.webView = WKWebView(frame: containerView.bounds)
        sut.isAppInBackground = { false }
        return sut
    }

    private func neverFinishingTask() -> Task<Void, Never> {
        Task { try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) }
    }

    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 2,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "condition not met within \(timeout)s", file: file, line: line)
    }
}

/// Parks `refreshNetworkInformation` calls while `shouldHold` is set, releasing them one at a
/// time in arrival order so tests can interleave hung and healthy load attempts deterministically.
private final class AsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var waiters = [CheckedContinuation<Void, Never>]()
    private var holding = false

    var shouldHold: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return holding
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            holding = newValue
        }
    }

    var waiterCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return waiters.count
    }

    func holdIfNeeded() async {
        guard shouldHold else { return }
        await withCheckedContinuation { continuation in
            lock.lock()
            waiters.append(continuation)
            lock.unlock()
        }
    }

    func releaseNext() {
        lock.lock()
        let waiter = waiters.isEmpty ? nil : waiters.removeFirst()
        lock.unlock()
        waiter?.resume()
    }
}
