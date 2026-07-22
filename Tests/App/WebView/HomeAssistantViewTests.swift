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
