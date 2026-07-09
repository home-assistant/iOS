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

@MainActor
final class WebViewControllerURLLoadingTests: XCTestCase {
    private var previousRefreshNetworkInformation: (() async -> Void)!

    override func setUp() {
        super.setUp()
        previousRefreshNetworkInformation = Current.connectivity.refreshNetworkInformation
        Current.connectivity.refreshNetworkInformation = {}
    }

    override func tearDown() {
        Current.connectivity.refreshNetworkInformation = previousRefreshNetworkInformation
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
