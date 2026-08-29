@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

@MainActor
final class HomeAssistantViewTests: XCTestCase {
    func testMakeWebViewControllerUsesProvidedServerAndHasNoInitialURLWithoutRestoration() {
        let server = Server.fake()
        let representable = FrontendView(
            server: server,
            onWebViewController: { _ in },
            overlayState: WebFrontendOverlayState()
        )

        let controller = representable.makeWebViewController()

        XCTAssertIdentical(controller.server, server)
        XCTAssertNil(controller.initialURL)
    }

    func testEachFrontendViewWiresItsControllerToItsOwnOverlayState() {
        let overlayStateA = WebFrontendOverlayState()
        let overlayStateB = WebFrontendOverlayState()

        let controllerA = FrontendView(server: Server.fake(), overlayState: overlayStateA).makeWebViewController()
        let controllerB = FrontendView(server: Server.fake(), overlayState: overlayStateB).makeWebViewController()

        XCTAssertIdentical(controllerA.overlayState, overlayStateA)
        XCTAssertIdentical(controllerB.overlayState, overlayStateB)
        XCTAssertNotIdentical(controllerA.overlayState, controllerB.overlayState)
    }

    func testFrontendViewWiresResetActionToController() {
        var resetCalled = false
        let reconnectManager = WebViewReconnectManager()

        let controller = FrontendView(
            server: Server.fake(),
            resetFrontendAction: { resetCalled = true },
            reconnectManager: reconnectManager,
            overlayState: WebFrontendOverlayState()
        ).makeWebViewController()

        controller.resetFrontendAction?()

        XCTAssertTrue(resetCalled)
        XCTAssertIdentical(controller.reconnectManager, reconnectManager)
    }

    func testHomeAssistantViewModelStartsWithStandbyLoaderUntilFrontendConnects() {
        let overlayState = WebFrontendOverlayState()
        overlayState.connectionState = .connected

        let sut = HomeAssistantViewModel(
            server: Server.fake(),
            overlayState: overlayState
        )

        XCTAssertTrue(sut.shouldShowStandByView)
        XCTAssertEqual(sut.standByOpacity, 1)
        XCTAssertEqual(overlayState.connectionState, .unknown)
        XCTAssertFalse(sut.loaderMinimumDurationElapsed)
    }

    func testConnectedHidesStandbyLoaderBeforeFrontendLoadedEventSupport() {
        let overlayState = WebFrontendOverlayState()
        let sut = HomeAssistantViewModel(
            server: server(version: Version(major: 2026, minor: 7, patch: 0)),
            overlayState: overlayState
        )
        sut.loaderMinimumDurationElapsed = true

        overlayState.connectionState = .connected

        XCTAssertFalse(sut.isFullScreenLoaderVisible)
    }

    func testConnectedDoesNotHideStandbyLoaderWhenFrontendLoadedEventIsSupported() {
        let overlayState = WebFrontendOverlayState()
        let sut = HomeAssistantViewModel(
            server: server(version: .frontendLoadedExternalBus),
            overlayState: overlayState
        )
        sut.loaderMinimumDurationElapsed = true

        overlayState.connectionState = .connected

        XCTAssertTrue(sut.isFullScreenLoaderVisible)
    }

    func testLoadedHidesStandbyLoaderWhenFrontendLoadedEventIsSupported() {
        let overlayState = WebFrontendOverlayState()
        let sut = HomeAssistantViewModel(
            server: server(version: .frontendLoadedExternalBus),
            overlayState: overlayState
        )
        sut.loaderMinimumDurationElapsed = true

        overlayState.connectionState = .loaded

        XCTAssertFalse(sut.isFullScreenLoaderVisible)
    }

    func testAppSideReloadRequiresFrontendLoadedAgainBeforeConnectedDismissesLoader() {
        let overlayState = WebFrontendOverlayState()
        let sut = HomeAssistantViewModel(
            server: server(version: .frontendLoadedExternalBus),
            overlayState: overlayState
        )
        sut.loaderMinimumDurationElapsed = true
        overlayState.connectionState = .loaded
        XCTAssertFalse(sut.isFullScreenLoaderVisible)

        // Pull-to-refresh / app-side refresh loads the document from scratch, so the fresh frontend
        // instance must fire `frontend/loaded` again before plain `connected` can dismiss the loader.
        overlayState.isLoading = true
        sut.loaderMinimumDurationElapsed = true
        overlayState.connectionState = .connected
        XCTAssertTrue(sut.isFullScreenLoaderVisible)

        overlayState.connectionState = .loaded
        XCTAssertFalse(sut.isFullScreenLoaderVisible)
    }

    func testConnectedDismissesLoaderAfterWebsocketBlipWithinSamePageLoad() {
        let overlayState = WebFrontendOverlayState()
        let sut = HomeAssistantViewModel(
            server: server(version: .frontendLoadedExternalBus),
            overlayState: overlayState
        )

        // `frontend/loaded` arrives while the loader minimum duration is still running, then the websocket
        // blips; the living page fires `loaded` only once, so the reconnect reports plain `connected`.
        overlayState.connectionState = .loaded
        overlayState.connectionState = .disconnected
        sut.loaderMinimumDurationElapsed = true
        overlayState.connectionState = .connected

        XCTAssertFalse(sut.isFullScreenLoaderVisible)
    }

    /// A page restored from WebKit's page cache never re-announces `frontend/loaded`, and external-bus
    /// messages that land while the app is backgrounded are dropped outright. Both leave the loader with no
    /// signal at all, so once the navigation itself has finished it has to give up rather than cover a
    /// working frontend forever.
    func testWatchdogDismissesStandbyLoaderWhenTheFrontendNeverReportsAfterLoading() async {
        let overlayState = WebFrontendOverlayState()
        let sut = HomeAssistantViewModel(
            server: server(version: .frontendLoadedExternalBus),
            overlayState: overlayState
        )
        sut.loaderWatchdogTimeout = .milliseconds(20)

        overlayState.isLoading = true
        overlayState.isLoading = false

        await waitUntil { !sut.isFullScreenLoaderMounted }
        XCTAssertFalse(sut.isFullScreenLoaderVisible)
        XCTAssertFalse(sut.shouldShowStandByView)
    }

    func testWatchdogLeavesStandbyViewUpWhenAnEmptyStateIsShowing() async {
        let overlayState = WebFrontendOverlayState()
        let sut = HomeAssistantViewModel(
            server: server(version: .frontendLoadedExternalBus),
            overlayState: overlayState
        )
        sut.loaderWatchdogTimeout = .milliseconds(20)

        overlayState.isLoading = true
        overlayState.isLoading = false
        overlayState.emptyState = emptyStateContent()

        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertTrue(sut.isFullScreenLoaderMounted)
        XCTAssertTrue(sut.isFullScreenLoaderVisible)
    }

    /// A navigation that is still in flight has not failed yet: the watchdog only counts down once the
    /// document itself has finished, so a slow load keeps the loader rather than exposing a blank web view.
    func testWatchdogDoesNotDismissStandbyLoaderWhileTheNavigationIsStillRunning() async {
        let overlayState = WebFrontendOverlayState()
        let sut = HomeAssistantViewModel(
            server: server(version: .frontendLoadedExternalBus),
            overlayState: overlayState
        )
        sut.loaderWatchdogTimeout = .milliseconds(20)

        overlayState.isLoading = true

        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertTrue(sut.isFullScreenLoaderMounted)
        XCTAssertTrue(sut.isFullScreenLoaderVisible)
    }

    func testForceDismissHidesStandbyLoaderRegardlessOfConnectionState() {
        let overlayState = WebFrontendOverlayState()
        let sut = HomeAssistantViewModel(
            server: server(version: .frontendLoadedExternalBus),
            overlayState: overlayState
        )
        XCTAssertTrue(sut.shouldShowStandByView)

        sut.forceDismissStandByView()

        XCTAssertFalse(sut.isFullScreenLoaderVisible)
        XCTAssertFalse(sut.shouldShowStandByView)
    }

    func testCleanCacheAndReloadClearsFrontendAssetCacheThenResetsFrontend() {
        let previousHandler = Current.websiteDataStoreHandler
        defer { Current.websiteDataStoreHandler = previousHandler }
        let handler = FakeWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = handler

        let overlayState = WebFrontendOverlayState()
        overlayState.showsNoActiveURL = true
        let sut = HomeAssistantViewModel(
            server: Server.fake(),
            overlayState: overlayState
        )
        let initialResetID = sut.webViewResetID

        sut.cleanCacheAndReload()

        XCTAssertEqual(handler.cleanCacheCallCount, 1)
        XCTAssertEqual(handler.lastDataTypes, WebsiteDataStoreHandlerImpl.frontendAssetDataTypes)

        handler.invokePendingCompletion()

        XCTAssertNotEqual(sut.webViewResetID, initialResetID)
        XCTAssertFalse(overlayState.showsNoActiveURL)
        XCTAssertTrue(sut.isFullScreenLoaderMounted)
    }

    private func server(version: Version) -> Server {
        Server.fake { info in
            info.version = version
        }
    }

    private func emptyStateContent() -> WebFrontendOverlayState.EmptyStateContent {
        WebFrontendOverlayState.EmptyStateContent(
            style: .disconnected,
            server: Server.fake(),
            showsErrorDetailsButton: false,
            availableReauthURLTypes: [],
            retryAction: {},
            settingsAction: {},
            errorDetailsAction: {},
            reauthAction: { _ in },
            dismissAction: {}
        )
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

private final class FakeWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    private(set) var cleanCacheCallCount = 0
    private(set) var lastDataTypes: Set<String>?
    private var pendingCompletion: (() -> Void)?

    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)?) {
        cleanCacheCallCount += 1
        lastDataTypes = dataTypes
        pendingCompletion = completion
    }

    func cleanFrontendAssetCacheIfNeeded(completion: ((Bool) -> Void)?) {}

    func invokePendingCompletion() {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?()
    }
}
