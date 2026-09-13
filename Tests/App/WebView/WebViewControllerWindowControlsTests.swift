@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

/// iPadOS 26 draws its window controls over the app's own content, so the web view has to start below
/// them — otherwise they land on the frontend's header, over the sidebar button.
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

    /// Full screen, and every device without window controls, report a corner-adapted safe area identical
    /// to the plain one — nothing to clear, so the web view stays edge to edge.
    func testWebViewTopInsetIsZeroWhenNothingIsReservedInTheCorners() {
        XCTAssertEqual(WebViewController.webViewTopInset(cornerAdaptedSafeAreaTop: 0, safeAreaTop: 0), 0)
        XCTAssertEqual(WebViewController.webViewTopInset(cornerAdaptedSafeAreaTop: 59, safeAreaTop: 59), 0)
    }

    /// The whole corner-adapted inset, not just the part beyond the safe area: the frontend insets its own
    /// content by whatever safe area the web view has left, so a partial offset would leave the header
    /// covered by exactly the safe-area part again.
    func testWebViewTopInsetIsTheWholeCornerAdaptedInsetWhenWindowControlsNeedRoom() {
        XCTAssertEqual(WebViewController.webViewTopInset(cornerAdaptedSafeAreaTop: 44, safeAreaTop: 0), 44)
        XCTAssertEqual(WebViewController.webViewTopInset(cornerAdaptedSafeAreaTop: 64, safeAreaTop: 20), 64)
    }

    /// Without window controls to clear, the web view keeps running to the very top of the window and the
    /// status-bar view stays out of the way.
    func testWebViewIsEdgeToEdgeWithoutWindowControls() {
        let sut = makeSUT()

        layOut(sut)

        XCTAssertEqual(sut.windowControlsTopInset, 0)
        XCTAssertEqual(sut.webViewTopConstraint?.constant, 0)
        XCTAssertEqual(sut.webView.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.isHidden, true)
    }

    /// Laying out is what picks the controls up: a window becoming full screen, or one being dragged out of
    /// full screen, announces itself as nothing more than a new layout pass.
    func testLayoutPushesTheWebViewBelowTheWindowControls() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }

        layOut(sut)

        XCTAssertEqual(sut.webViewTopConstraint?.constant, 44)
        XCTAssertEqual(sut.webView.frame.minY, 44)
    }

    /// The status-bar view fills the room the web view gives up, so the controls sit on the header colour
    /// rather than on a strip of whatever the page happens to be showing.
    func testStatusBarViewFillsTheRoomTheWebViewGivesUp() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }

        layOut(sut)

        XCTAssertEqual(sut.statusBarView?.isHidden, false)
        XCTAssertEqual(sut.statusBarView?.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.frame.height, 44)
    }

    /// Going back to full screen hands the room back: the controls are gone, so keeping the web view below
    /// where they were would just be a permanent strip of wasted screen.
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

    /// The frontend's Assist button is drawn in the web view, so the anchor the zoom transition grows out
    /// of has to follow it down rather than stay where the window controls are.
    func testAssistZoomAnchorFollowsTheWebViewBelowTheWindowControls() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }

        layOut(sut)

        XCTAssertEqual(sut.assistZoomAnchorView?.frame.minY, 44 + AssistZoomAnchorView.topInset)
    }

    /// Twice over: the first pass is what reads the window controls and moves the web view, the second is
    /// what lays the moved views out.
    private func layOut(_ sut: WebViewController) {
        sut.view.layoutIfNeeded()
        sut.view.layoutIfNeeded()
    }

    private func makeSUT() -> WebViewController {
        let sut = WebViewController(server: server)
        // `webView` and the status-bar view are built in `viewDidLoad`, along with the constraints between
        // them that the inset moves.
        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(x: 0, y: 0, width: 820, height: 1180)
        return sut
    }
}
