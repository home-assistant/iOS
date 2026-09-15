@testable import HomeAssistant
@testable import Shared
import UIKit
import WebKit
import XCTest

@MainActor
final class WebViewControllerBlankFrontendTests: XCTestCase {
    private var previousWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol!
    private var previousFlightGreetingsEnabled: Bool!
    private var previousLastActiveURLPath: String?
    private var previousLastActiveServerIdentifier: String?
    private var websiteDataStoreHandler: MockWebsiteDataStoreHandler!

    override func setUp() {
        super.setUp()
        previousWebsiteDataStoreHandler = Current.websiteDataStoreHandler
        websiteDataStoreHandler = MockWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = websiteDataStoreHandler
        previousFlightGreetingsEnabled = Current.settingsStore.flightGreetingsEnabled
        Current.settingsStore.flightGreetingsEnabled = false
        previousLastActiveURLPath = Current.settingsStore.lastActiveURLPath
        previousLastActiveServerIdentifier = Current.settingsStore.lastActiveServerIdentifier
    }

    override func tearDown() {
        Current.websiteDataStoreHandler = previousWebsiteDataStoreHandler
        Current.settingsStore.flightGreetingsEnabled = previousFlightGreetingsEnabled
        Current.settingsStore.lastActiveURLPath = previousLastActiveURLPath
        Current.settingsStore.lastActiveServerIdentifier = previousLastActiveServerIdentifier
        super.tearDown()
    }

    func testRenderProbeReportsNothingRenderedWithoutAWebView() async {
        let sut = makeSUT()
        sut.webView = nil

        let hasRendered = await sut.hasRenderedFrontend()

        XCTAssertFalse(hasRendered)
    }

    func testRenderProbeReportsRenderedForAPageWithContent() async throws {
        let sut = makeSUT()
        let baseURL = try XCTUnwrap(URL(string: "https://example.com/lovelace/0"))
        sut.webView.loadHTMLString("<html><body><img src=\"icon.png\"></body></html>", baseURL: baseURL)
        await waitUntil { sut.webView.url != nil && !sut.webView.isLoading }

        let hasRendered = await sut.hasRenderedFrontend()

        XCTAssertTrue(hasRendered)
    }

    func testRenderProbeReportsNothingRenderedForAnEmptyPage() async throws {
        let sut = makeSUT()
        let baseURL = try XCTUnwrap(URL(string: "https://example.com/lovelace/0"))
        sut.webView.loadHTMLString("<html><body></body></html>", baseURL: baseURL)
        await waitUntil { sut.webView.url != nil && !sut.webView.isLoading }

        let hasRendered = await sut.hasRenderedFrontend()

        XCTAssertFalse(hasRendered)
    }

    func testRenderProbeUsesTheInjectedCheckWhenThereIsOne() async {
        let sut = makeSUT()
        sut.hasRenderedFrontendCheck = { $0(true) }

        let hasRendered = await sut.hasRenderedFrontend()

        XCTAssertTrue(hasRendered)
    }

    func testRecoveringABlankFrontendCleansItsCacheBeforeReloading() {
        let sut = makeSUT()

        XCTAssertTrue(sut.recoverFromBlankFrontend())

        XCTAssertEqual(websiteDataStoreHandler.cleanCacheCallCount, 1)
        XCTAssertEqual(websiteDataStoreHandler.lastDataTypes, WebsiteDataStoreHandlerImpl.frontendAssetDataTypes)
        XCTAssertEqual(sut.blankFrontendRecoveryAttempts, 1)
    }

    func testRecoveringABlankRestoredPathFallsBackToTheFrontendRoot() async throws {
        let server = Server.fake()
        let sut = makeSUT(server: server)
        let baseURL = try XCTUnwrap(URL(string: "https://home.local/lovelace/0"))
        sut.webView.loadHTMLString("<html><body></body></html>", baseURL: baseURL)
        await waitUntil { sut.webView.url?.path == "/lovelace/0" }
        sut.initialURLPath = "/lovelace/0"
        Current.settingsStore.lastActiveServerIdentifier = server.identifier.rawValue
        Current.settingsStore.lastActiveURLPath = "/lovelace/0"

        XCTAssertTrue(sut.recoverFromBlankFrontend())

        XCTAssertNil(sut.initialURLPath)
        XCTAssertNil(Current.settingsStore.lastActiveURLPath)
        XCTAssertEqual(websiteDataStoreHandler.cleanCacheCallCount, 0)
    }

    func testRecoveringABlankFrontendIsRefusedOnceItsAttemptIsSpent() {
        let sut = makeSUT()

        XCTAssertTrue(sut.recoverFromBlankFrontend())

        XCTAssertFalse(sut.recoverFromBlankFrontend())
        XCTAssertEqual(websiteDataStoreHandler.cleanCacheCallCount, 1)
    }

    func testAFrontendThatReportsItselfGetsItsRecoveryAttemptsBack() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        sut.recoverFromBlankFrontend()
        sut.contentProcessTerminations = 2

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.loaded.rawValue)

        XCTAssertEqual(sut.blankFrontendRecoveryAttempts, 0)
        XCTAssertEqual(sut.contentProcessTerminations, 0)
    }

    func testARestoredPathIsOnlySuspectWhileItIsTheDisplayedPage() {
        XCTAssertTrue(WebViewController.isShowingRestoredPath(
            restoredPath: "/lovelace/0?edit=1",
            currentPath: "/lovelace/0"
        ))
        XCTAssertFalse(WebViewController.isShowingRestoredPath(
            restoredPath: "/lovelace/0",
            currentPath: "/config/dashboard"
        ))
        XCTAssertFalse(WebViewController.isShowingRestoredPath(restoredPath: nil, currentPath: "/lovelace/0"))
        XCTAssertFalse(WebViewController.isShowingRestoredPath(restoredPath: "/lovelace/0", currentPath: nil))
    }

    func testForgettingARestoredPathKeepsItFromComingBackOnTheNextLaunch() {
        let server = Server.fake()
        let sut = makeSUT(server: server)
        sut.initialURLPath = "/lovelace/0"
        sut.initialURL = URL(string: "https://example.com/lovelace/0")
        Current.settingsStore.lastActiveServerIdentifier = server.identifier.rawValue
        Current.settingsStore.lastActiveURLPath = "/lovelace/0"

        sut.forgetRestoredPath()

        XCTAssertNil(sut.initialURLPath)
        XCTAssertNil(sut.initialURL)
        XCTAssertNil(Current.settingsStore.lastActiveURLPath)
    }

    func testForgettingARestoredPathLeavesAnotherServersSavedPathAlone() {
        let sut = makeSUT()
        sut.initialURLPath = "/lovelace/0"
        Current.settingsStore.lastActiveServerIdentifier = "another-server"
        Current.settingsStore.lastActiveURLPath = "/config/dashboard"

        sut.forgetRestoredPath()

        XCTAssertNil(sut.initialURLPath)
        XCTAssertEqual(Current.settingsStore.lastActiveURLPath, "/config/dashboard")
    }

    func testATerminatedContentProcessIsIgnoredBehindTheNoActiveURLState() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        overlayState.showsNoActiveURL = true
        sut.overlayState = overlayState

        sut.handleContentProcessTermination()

        XCTAssertEqual(sut.contentProcessTerminations, 0)
        XCTAssertNil(overlayState.emptyState)
    }

    func testAFrontendThatOnlyConnectsKeepsItsRecoveryAttemptSpent() {
        let sut = makeSUT(server: .fake(update: { info in info.version = .frontendLoadedExternalBus }))
        sut.overlayState = WebFrontendOverlayState()
        sut.recoverFromBlankFrontend()

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)

        XCTAssertEqual(sut.blankFrontendRecoveryAttempts, 1)
    }

    func testAnOlderFrontendGetsItsRecoveryAttemptsBackOnConnected() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        sut.recoverFromBlankFrontend()

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)

        XCTAssertEqual(sut.blankFrontendRecoveryAttempts, 0)
    }

    func testNavigatingToTheRootWithoutAnActiveURLShowsTheNoActiveURLState() async {
        let sut = makeSUT(server: .fake(update: { info in
            info.connection.set(address: nil, for: .external)
            _ = info.connection.evaluateActiveURL()
        }))
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.navigateToRoot()

        await waitUntil { overlayState.showsNoActiveURL }
    }

    func testARepeatedlyTerminatedContentProcessEndsUpOnTheEmptyState() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState

        sut.handleContentProcessTermination()

        XCTAssertEqual(sut.contentProcessTerminations, 1)
        XCTAssertEqual(websiteDataStoreHandler.cleanCacheCallCount, 0)
        XCTAssertNil(overlayState.emptyState)

        sut.handleContentProcessTermination()

        XCTAssertEqual(websiteDataStoreHandler.cleanCacheCallCount, 1)
        XCTAssertNil(overlayState.emptyState)

        sut.handleContentProcessTermination()

        XCTAssertEqual(overlayState.emptyState?.style, .disconnected)
    }

    func testATerminatedContentProcessShowsTheEmptyStateWhenRecoveryIsAlreadySpent() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.blankFrontendRecoveryAttempts = WebViewController.maximumBlankFrontendRecoveryAttempts

        sut.handleContentProcessTermination()
        sut.handleContentProcessTermination()

        XCTAssertEqual(overlayState.emptyState?.style, .disconnected)
        XCTAssertEqual(websiteDataStoreHandler.cleanCacheCallCount, 0)
    }

    func testTheWebKitDelegateReloadsAPageWhoseContentProcessDied() async throws {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        let baseURL = try XCTUnwrap(URL(string: "https://home.local/lovelace/0"))
        sut.webView.loadHTMLString("<html><body><img src=\"icon.png\"></body></html>", baseURL: baseURL)
        await waitUntil { sut.webView.url?.path == "/lovelace/0" }

        sut.webViewWebContentProcessDidTerminate(sut.webView)

        XCTAssertEqual(sut.contentProcessTerminations, 1)
        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertEqual(websiteDataStoreHandler.cleanCacheCallCount, 0)
    }

    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(condition(), "condition not met within \(timeout)s", file: file, line: line)
    }

    private func makeSUT(server: Server = .fake()) -> WebViewController {
        let sut = WebViewController(server: server)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        sut.setValue(containerView, forKey: "view")
        sut.webView = WKWebView(frame: containerView.bounds)
        return sut
    }
}
