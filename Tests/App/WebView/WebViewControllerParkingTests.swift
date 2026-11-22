@testable import HomeAssistant
@testable import Shared
import UIKit
import WebKit
import XCTest

/// A Mac window that other windows cover completely keeps its scene active, so nothing tells its
/// frontend to stop rendering. The controller parks the web view for as long as no window of the app
/// is visible.
@MainActor
final class WebViewControllerParkingTests: XCTestCase {
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var isWindowVisible = true
    private var scheduledActions: [@MainActor () -> Void] = []
    private var cancelledTimers = 0

    override func setUp() {
        super.setUp()
        previousCachedApis = Current.cachedApis
    }

    override func tearDown() {
        // The empty state caches an API for its server, and one left behind stays registered with the
        // app's sensor container for the rest of the run.
        Current.cachedApis = previousCachedApis
        previousCachedApis = nil
        isWindowVisible = true
        scheduledActions = []
        cancelledTimers = 0
        super.tearDown()
    }

    func testAFrontendIsParkedOnceNoWindowHasBeenVisibleForTheDelay() throws {
        let sut = makeSUT()
        isWindowVisible = false

        sut.updateFrontendParking()
        XCTAssertFalse(sut.webViewParking.isParked, "switching to another app for a moment parks nothing")

        try parkAfterTheDelay()

        XCTAssertTrue(sut.webViewParking.isParked)
        XCTAssertNil(sut.webView.superview)
        XCTAssertFalse(sut.isFrontendOnScreen)
    }

    func testAWindowThatIsBackBeforeTheDelayLeavesTheFrontendAlone() {
        let sut = makeSUT()
        isWindowVisible = false
        sut.updateFrontendParking()

        isWindowVisible = true
        sut.updateFrontendParking()

        XCTAssertEqual(cancelledTimers, 1)
        XCTAssertFalse(sut.webViewParking.isParked)
        XCTAssertTrue(sut.isFrontendOnScreen)
    }

    /// The notification about a window that is back and the timer can cross.
    func testATimerThatFiresWithAWindowVisibleParksNothing() throws {
        let sut = makeSUT()
        isWindowVisible = false
        sut.updateFrontendParking()
        isWindowVisible = true

        try XCTUnwrap(scheduledActions.first)()

        XCTAssertFalse(sut.webViewParking.isParked)
        XCTAssertTrue(sut.webView.superview === sut.view)
    }

    func testARetiredFrontendIsNotParked() throws {
        let sut = makeSUT()
        isWindowVisible = false
        sut.updateFrontendParking()

        sut.retireFrontend()
        try XCTUnwrap(scheduledActions.first)()
        sut.updateFrontendParking()

        XCTAssertFalse(sut.webViewParking.isParked)
        XCTAssertEqual(scheduledActions.count, 1)
    }

    func testAVisibleWindowPutsTheFrontendBackWithItsLayout() throws {
        let sut = makeSUT()
        let statusBarView = UIView()
        sut.view.addSubview(statusBarView)
        sut.statusBarView = statusBarView
        sut.setupWebViewConstraints(statusBarView: statusBarView)
        let anchor = AssistZoomAnchorView.install(in: sut.view, alignedTo: sut.webView)
        sut.assistZoomAnchorView = anchor
        isWindowVisible = false
        sut.updateFrontendParking()
        try parkAfterTheDelay()

        isWindowVisible = true
        sut.updateFrontendParking()

        XCTAssertFalse(sut.webViewParking.isParked)
        XCTAssertTrue(sut.webView.superview === sut.view)
        XCTAssertTrue(sut.isFrontendOnScreen)
        XCTAssertEqual(sut.webViewTopConstraint?.isActive, true)
        let pinnedEdges = sut.view.constraints.filter { $0.firstItem === sut.webView && $0.isActive }
        XCTAssertEqual(pinnedEdges.count, 4, "left, right, bottom and top went with the web view")
        XCTAssertNil(anchor.superview, "its constraints to the web view went with the web view")
        XCTAssertTrue(sut.assistZoomAnchorView?.superview === sut.view)
    }

    /// Five minutes after its page went hidden the frontend closes its connection. Nobody can see an
    /// empty state about that, and showing one starts the reconnects that would rebuild the frontend
    /// in the window it was parked for. It waits for a window that is back, and gets its grace period
    /// then.
    func testTheDisconnectedEmptyStateWaitsForAVisibleWindow() throws {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        isWindowVisible = false
        sut.updateFrontendParking()
        try parkAfterTheDelay()
        XCTAssertTrue(sut.didEnterBackgroundSinceLastActivation)
        sut.connectionState = .disconnected

        sut.showEmptyState()

        XCTAssertNil(overlayState.emptyState)
        XCTAssertTrue(sut.isEmptyStateDeferredUntilActive)

        isWindowVisible = true
        sut.updateFrontendParking()
        defer { sut.emptyStateTimer?.invalidate() }

        XCTAssertFalse(sut.isEmptyStateDeferredUntilActive)
        XCTAssertFalse(sut.didEnterBackgroundSinceLastActivation)
        XCTAssertNil(overlayState.emptyState)
        XCTAssertNotNil(sut.emptyStateTimer)
    }

    /// An empty state that is up goes on reconnecting, and every reconnect would rebuild the frontend in
    /// the window nobody can see.
    func testParkingTakesDownADisconnectedEmptyStateUntilAWindowIsBack() throws {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.connectionState = .disconnected
        sut.showEmptyState()
        XCTAssertNotNil(overlayState.emptyState)

        isWindowVisible = false
        sut.updateFrontendParking()
        try parkAfterTheDelay()

        XCTAssertNil(overlayState.emptyState)
        XCTAssertTrue(sut.isEmptyStateDeferredUntilActive)

        isWindowVisible = true
        sut.updateFrontendParking()
        defer { sut.emptyStateTimer?.invalidate() }

        XCTAssertFalse(sut.isEmptyStateDeferredUntilActive)
        XCTAssertNotNil(sut.emptyStateTimer)
    }

    /// A scene can become active while its window is still covered. The grace period belongs to the
    /// moment the web view is back.
    func testASceneThatActivatesWhileTheFrontendIsParkedStartsNoGracePeriod() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first)
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        isWindowVisible = false
        sut.updateFrontendParking()
        try parkAfterTheDelay()
        sut.connectionState = .disconnected
        sut.showEmptyState()

        sut.sceneDidActivate(Notification(name: UIScene.didActivateNotification, object: scene))

        XCTAssertTrue(sut.isEmptyStateDeferredUntilActive)
        XCTAssertNil(sut.emptyStateTimer)
    }

    /// Hiding the app parks the frontend as well, and there the scene reports its own return.
    func testASceneThatIsNotActiveYetIsLeftToReportItsOwnActivation() throws {
        let sut = makeSUT()
        isWindowVisible = false
        sut.updateFrontendParking()
        try parkAfterTheDelay()
        sut.isSceneActive = { _ in false }

        isWindowVisible = true
        sut.updateFrontendParking()

        XCTAssertFalse(sut.webViewParking.isParked)
        XCTAssertTrue(sut.didEnterBackgroundSinceLastActivation)
    }

    private func parkAfterTheDelay() throws {
        try XCTUnwrap(scheduledActions.last)()
    }

    private func makeSUT() -> WebViewController {
        let sut = WebViewController(server: .fake())
        sut.isSceneActive = { _ in true }
        sut.isAppInBackground = { false }
        sut.isAnyAppWindowVisible = { [unowned self] in isWindowVisible }
        sut.webViewParking = WebViewParking(
            delay: 30,
            scheduleTimer: { [unowned self] _, action in
                scheduledActions.append(action)
                return { [unowned self] in cancelledTimers += 1 }
            }
        )
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        // KVC-setting the view bypasses loadView/viewDidLoad, so the web view is provided explicitly.
        sut.setValue(containerView, forKey: "view")
        let webView = WKWebView(frame: containerView.bounds)
        containerView.addSubview(webView)
        sut.webView = webView
        return sut
    }
}
