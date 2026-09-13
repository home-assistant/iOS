@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

/// iPadOS 26 draws its window controls over the app, so the web view has to start below them.
@MainActor
final class WebViewControllerWindowControlsTests: XCTestCase {
    private var previousServers: ServerManager!
    private var servers: FakeServerManager!
    private var server: Server!

    override func setUp() async throws {
        previousServers = Current.servers
        servers = FakeServerManager(initial: 0)
        server = servers.addFake()
        Current.servers = servers
    }

    override func tearDown() async throws {
        Current.servers = previousServers
        previousServers = nil
        servers = nil
        server = nil
    }

    /// Full screen, and every device without window controls, report the corner-adapted safe area unchanged.
    func testWebViewTopInsetIsZeroWhenNothingIsReservedInTheCorners() {
        XCTAssertEqual(WebViewController.webViewTopInset(cornerAdaptedSafeAreaTop: 0, safeAreaTop: 0), 0)
        XCTAssertEqual(WebViewController.webViewTopInset(cornerAdaptedSafeAreaTop: 59, safeAreaTop: 59), 0)
    }

    /// The whole inset, not only the part beyond the safe area, which the frontend no longer insets itself by.
    func testWebViewTopInsetIsTheWholeCornerAdaptedInsetWhenWindowControlsNeedRoom() {
        XCTAssertEqual(WebViewController.webViewTopInset(cornerAdaptedSafeAreaTop: 44, safeAreaTop: 0), 44)
        XCTAssertEqual(WebViewController.webViewTopInset(cornerAdaptedSafeAreaTop: 64, safeAreaTop: 20), 64)
    }

    /// Without controls to clear, the web view runs to the top of the window and the status-bar view hides.
    func testWebViewIsEdgeToEdgeWithoutWindowControls() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { view in view.safeAreaInsets.top }

        layOut(sut)

        XCTAssertEqual(sut.windowControlsTopInset, 0)
        XCTAssertEqual(sut.webViewTopConstraint?.constant, 0)
        XCTAssertEqual(sut.webView.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.isHidden, true)
    }

    /// Laying out is what picks the controls up; entering and leaving full screen is only a new layout pass.
    func testLayoutPushesTheWebViewBelowTheWindowControls() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }

        layOut(sut)

        XCTAssertEqual(sut.webViewTopConstraint?.constant, 44)
        XCTAssertEqual(sut.webView.frame.minY, 44)
    }

    /// The status-bar view fills the room the web view gives up, so the controls sit on the header colour.
    func testStatusBarViewFillsTheRoomTheWebViewGivesUp() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }

        layOut(sut)

        XCTAssertEqual(sut.statusBarView?.isHidden, false)
        XCTAssertEqual(sut.statusBarView?.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.frame.height, 44)
    }

    /// Going back to full screen hands the room back, rather than leaving a permanent strip of wasted screen.
    func testWebViewReturnsToTheTopWhenTheWindowControlsGoAway() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }
        layOut(sut)

        sut.cornerAdaptedSafeAreaTop = { view in view.safeAreaInsets.top }
        sut.view.setNeedsLayout()
        layOut(sut)

        XCTAssertEqual(sut.webViewTopConstraint?.constant, 0)
        XCTAssertEqual(sut.webView.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.isHidden, true)
    }

    /// The default reader never reports less room than the plain safe area, whatever the device reserves.
    func testCornerAdaptedSafeAreaTopIsAtLeastThePlainSafeAreaTop() {
        let sut = makeSUT()

        XCTAssertGreaterThanOrEqual(sut.cornerAdaptedSafeAreaTop(sut.view), sut.view.safeAreaInsets.top)
    }

    /// The frontend's Assist button is drawn in the web view, so the zoom anchor has to follow it down.
    func testAssistZoomAnchorFollowsTheWebViewBelowTheWindowControls() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }

        layOut(sut)

        XCTAssertEqual(sut.assistZoomAnchorView?.frame.minY, 44 + AssistZoomAnchorView.topInset)
    }

    /// Twice over: the first pass moves the web view, the second lays the moved views out.
    private func layOut(_ sut: WebViewController) {
        sut.view.layoutIfNeeded()
        sut.view.layoutIfNeeded()
    }

    private func makeSUT() -> WebViewController {
        let sut = WebViewController(server: server)
        // `viewDidLoad` builds `webView`, the status-bar view, and the constraints the inset moves.
        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(x: 0, y: 0, width: 820, height: 1180)
        return sut
    }
}
