@testable import HomeAssistant
@testable import Shared
import UIKit
import WebKit
import XCTest

/// SwiftUI dismantles a `FrontendView`'s controller on a reset, on a server switch and when its window
/// goes, and the view model drops the tab bar's. What still references the controller afterwards must
/// not keep its frontend running.
@MainActor
final class WebViewControllerRetirementTests: XCTestCase {
    private var previousWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol!
    private var websiteDataStoreHandler: CountingWebsiteDataStoreHandler!

    override func setUp() {
        super.setUp()
        previousWebsiteDataStoreHandler = Current.websiteDataStoreHandler
        websiteDataStoreHandler = CountingWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = websiteDataStoreHandler
    }

    override func tearDown() {
        Current.websiteDataStoreHandler = previousWebsiteDataStoreHandler
        websiteDataStoreHandler = nil
        super.tearDown()
    }

    func testDismantlingAFrontendViewRetiresItsController() {
        let controller = FrontendView(server: .fake(), overlayState: WebFrontendOverlayState())
            .makeWebViewController()

        FrontendView.dismantleUIViewController(controller, coordinator: ())

        XCTAssertTrue(controller.isRetired)
    }

    /// The tab bar's slot hosts a controller the view model built itself, so the view model is the only
    /// one who can retire it when it drops it.
    func testResettingTheFrontendRetiresTheControllerItDrops() {
        let viewModel = HomeAssistantViewModel(server: .fake())
        let controller = makeSUT()
        viewModel.handleWebViewController(controller)

        viewModel.resetWebFrontend()

        XCTAssertTrue(controller.isRetired)
        XCTAssertNil(viewModel.webViewController)
    }

    /// A server switch or a closing window drops the view model without a reset, and with the tab bar
    /// on no `FrontendView` is there to dismantle the controller it still holds.
    func testDroppingTheViewModelRetiresTheControllerItStillHolds() {
        let controller = makeSUT()
        weak var droppedModel: HomeAssistantViewModel?
        autoreleasepool {
            let viewModel = HomeAssistantViewModel(server: .fake())
            droppedModel = viewModel
            viewModel.handleWebViewController(controller)
        }

        XCTAssertNil(droppedModel, "the standby-loader tasks must not hold the model past its owner")
        XCTAssertTrue(controller.isRetired)
    }

    /// Deep links, the kiosk dashboard and a reload after a server version change all go through
    /// `load(request:)` or `reload()`, so a retired controller refuses there rather than in each of them.
    func testRetiringTakesThePageDownAndKeepsItDown() throws {
        let (sut, webView) = makeSUTWithRecordingWebView()
        let serverURL = try XCTUnwrap(URL(string: "https://example.com/lovelace/0"))

        sut.retireFrontend()
        XCTAssertEqual(webView.loadedURLs, [WebViewController.blankPageURLString])

        sut.load(request: URLRequest(url: serverURL))
        sut.reload()
        sut.goBack()
        sut.goForward()
        sut.retireFrontend()

        XCTAssertEqual(webView.loadedURLs, [WebViewController.blankPageURLString])
        XCTAssertEqual(webView.reloadCount, 0)
        XCTAssertEqual(webView.historyMoves, 0, "the blank page keeps the frontend in the history")
    }

    /// The connection and activation notifications reach every controller alive, retired ones included.
    func testARetiredControllerDoesNotLoadTheActiveURL() {
        let sut = makeSUT()
        sut.retireFrontend()

        sut.loadActiveURLIfNeeded()

        XCTAssertEqual(websiteDataStoreHandler.cleanFrontendAssetCacheIfNeededCallCount, 0)
        XCTAssertNil(sut.loadActiveURLTask)
    }

    /// The cache check before a load is asynchronous, so a retirement can land while it is pending.
    func testRetiringWhileTheCacheCheckIsPendingStartsNoLoad() {
        let sut = makeSUT()
        websiteDataStoreHandler.holdsCompletions = true
        sut.loadActiveURLIfNeeded()
        XCTAssertEqual(websiteDataStoreHandler.cleanFrontendAssetCacheIfNeededCallCount, 1)

        sut.retireFrontend()
        websiteDataStoreHandler.completeHeldCacheChecks()

        XCTAssertNil(sut.loadActiveURLTask)
    }

    /// An attempt already running re-checks cancellation after every await, so cancelling it is what
    /// keeps it from evaluating the frontend's reload script or navigating once it wakes up.
    func testRetiringCancelsAnActiveURLAttemptInFlight() {
        let sut = makeSUT()
        let inFlight = Task<Void, Never> { _ = try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) }
        sut.loadActiveURLTask = inFlight
        sut.loadActiveURLTaskStartDate = Current.date()

        sut.retireFrontend()

        XCTAssertTrue(inFlight.isCancelled)
        XCTAssertNil(sut.loadActiveURLTask)
    }

    /// A publish still resolving its entity holds the activity and would make it current when it lands.
    func testRetiringCancelsAnOnscreenContentPublishInFlight() {
        let sut = makeSUT()
        let inFlight = Task<Void, Never> { _ = try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) }
        sut.onscreenContentTask = inFlight

        sut.retireFrontend()

        XCTAssertTrue(inFlight.isCancelled)
    }

    /// The overlay state and reconnect manager are the view model's, shared with the replacement
    /// controller, and the blank page's title would make the user activity current over the
    /// replacement's.
    func testRetiringLetsGoOfWhatItSharesWithItsReplacement() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        sut.reconnectManager = WebViewReconnectManager()

        sut.retireFrontend()

        XCTAssertNil(sut.overlayState)
        XCTAssertNil(sut.reconnectManager)
        XCTAssertNil(sut.userActivity)
    }

    private func makeSUT() -> WebViewController {
        makeSUTWithRecordingWebView().controller
    }

    private func makeSUTWithRecordingWebView() -> (controller: WebViewController, webView: RecordingWebView) {
        let sut = WebViewController(server: .fake())
        sut.isSceneActive = { _ in true }
        sut.isAppInBackground = { false }
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        // KVC-setting the view bypasses loadView/viewDidLoad, so the web view is provided explicitly.
        sut.setValue(containerView, forKey: "view")
        let webView = RecordingWebView(frame: containerView.bounds)
        sut.webView = webView
        return (sut, webView)
    }
}

/// Records what it is asked to load instead of loading it, so a refused load is a fact rather than a
/// page that happened not to arrive in time.
private final class RecordingWebView: WKWebView {
    private(set) var loadedURLs = [String]()
    private(set) var reloadCount = 0
    private(set) var historyMoves = 0

    override func load(_ request: URLRequest) -> WKNavigation? {
        loadedURLs.append(request.url?.absoluteString ?? "nil")
        return nil
    }

    override func reload() -> WKNavigation? {
        reloadCount += 1
        return nil
    }

    override func goBack() -> WKNavigation? {
        historyMoves += 1
        return nil
    }

    override func goForward() -> WKNavigation? {
        historyMoves += 1
        return nil
    }
}

private final class CountingWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    private(set) var cleanFrontendAssetCacheIfNeededCallCount = 0
    /// Keeps the cache check pending until `completeHeldCacheChecks()`, the way the real one is
    /// asynchronous.
    var holdsCompletions = false
    private var heldCompletions = [(Bool) -> Void]()

    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)?) {
        completion?()
    }

    func cleanFrontendAssetCacheIfNeeded(completion: ((Bool) -> Void)?) {
        cleanFrontendAssetCacheIfNeededCallCount += 1
        if holdsCompletions, let completion {
            heldCompletions.append(completion)
        } else {
            completion?(false)
        }
    }

    func completeHeldCacheChecks() {
        let completions = heldCompletions
        heldCompletions = []
        completions.forEach { $0(false) }
    }
}
