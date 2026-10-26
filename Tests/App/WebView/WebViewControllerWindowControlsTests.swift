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

    /// A window whose corners reserve no more than the plain safe area has nothing to clear.
    func testWebViewTopInsetIsZeroWhenNothingIsReservedInTheCorners() {
        XCTAssertEqual(
            WebViewController.webViewTopInset(
                cornerAdaptedSafeAreaTop: 0,
                safeAreaTop: 0,
                idiom: .pad,
                isWindowed: true
            ),
            0
        )
        XCTAssertEqual(
            WebViewController.webViewTopInset(
                cornerAdaptedSafeAreaTop: 59,
                safeAreaTop: 59,
                idiom: .pad,
                isWindowed: true
            ),
            0
        )
    }

    /// The whole inset, not only the part beyond the safe area, which the frontend no longer insets itself by.
    func testWebViewTopInsetIsTheWholeCornerAdaptedInsetWhenWindowControlsNeedRoom() {
        XCTAssertEqual(
            WebViewController.webViewTopInset(
                cornerAdaptedSafeAreaTop: 44,
                safeAreaTop: 0,
                idiom: .pad,
                isWindowed: true
            ),
            44
        )
        XCTAssertEqual(
            WebViewController.webViewTopInset(
                cornerAdaptedSafeAreaTop: 64,
                safeAreaTop: 20,
                idiom: .pad,
                isWindowed: true
            ),
            64
        )
    }

    /// Full screen draws no window controls: hiding the status bar there must not leave the room it freed
    /// reserved, however much the display's rounded corners adapt the safe area.
    func testWebViewTopInsetIsZeroInFullScreenWhateverTheCornersReserve() {
        XCTAssertEqual(
            WebViewController.webViewTopInset(
                cornerAdaptedSafeAreaTop: 24,
                safeAreaTop: 0,
                idiom: .pad,
                isWindowed: false
            ),
            0
        )
        XCTAssertEqual(
            WebViewController.webViewTopInset(
                cornerAdaptedSafeAreaTop: 64,
                safeAreaTop: 20,
                idiom: .pad,
                isWindowed: false
            ),
            0
        )
    }

    /// No iPhone draws window controls, so a rounded display's corner adaptation must not shrink the web view.
    func testWebViewTopInsetIsZeroOnIPhoneWhateverTheCornersReserve() {
        XCTAssertEqual(
            WebViewController.webViewTopInset(
                cornerAdaptedSafeAreaTop: 17,
                safeAreaTop: 0,
                idiom: .phone,
                isWindowed: true
            ),
            0
        )
        XCTAssertEqual(
            WebViewController.webViewTopInset(
                cornerAdaptedSafeAreaTop: 64,
                safeAreaTop: 20,
                idiom: .phone,
                isWindowed: true
            ),
            0
        )
    }

    /// Without controls to clear, the web view runs to the top of the window and the status-bar view hides.
    func testWebViewIsEdgeToEdgeWithoutWindowControls() {
        let sut = makeSUT(idiom: .pad)
        sut.cornerAdaptedSafeAreaTop = { view in view.safeAreaInsets.top }

        layOut(sut)

        XCTAssertEqual(sut.windowControlsTopInset, 0)
        XCTAssertEqual(sut.webViewTopConstraint?.constant, 0)
        XCTAssertEqual(sut.webView.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.isHidden, true)
    }

    /// A rounded iPhone display reserves nothing: the web content owns the screen, scrim and all.
    func testWebViewStaysEdgeToEdgeOnIPhoneWithRoundedCorners() {
        let sut = makeSUT(idiom: .phone)
        sut.cornerAdaptedSafeAreaTop = { _ in 17 }

        layOut(sut)

        XCTAssertEqual(sut.windowControlsTopInset, 0)
        XCTAssertEqual(sut.webViewTopConstraint?.constant, 0)
        XCTAssertEqual(sut.webView.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.isHidden, true)
    }

    /// Laying out is what picks the controls up; entering and leaving full screen is only a new layout pass.
    func testLayoutPushesTheWebViewBelowTheWindowControls() {
        let sut = makeSUT(idiom: .pad)
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }

        layOut(sut)

        XCTAssertEqual(sut.webViewTopConstraint?.constant, 44)
        XCTAssertEqual(sut.webView.frame.minY, 44)
    }

    /// The status-bar view fills the room the web view gives up, so the controls sit on the header colour.
    func testStatusBarViewFillsTheRoomTheWebViewGivesUp() {
        let sut = makeSUT(idiom: .pad)
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }

        layOut(sut)

        XCTAssertEqual(sut.statusBarView?.isHidden, false)
        XCTAssertEqual(sut.statusBarView?.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.frame.height, 44)
    }

    /// Going back to full screen hands the room back, rather than leaving a permanent strip of wasted screen.
    func testWebViewReturnsToTheTopWhenTheWindowControlsGoAway() {
        let sut = makeSUT(idiom: .pad)
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

    /// The default reader answers with the idiom the frontend is actually being laid out in.
    func testUserInterfaceIdiomReadsTheViewsTrait() {
        let sut = WebViewController(server: server)
        sut.loadViewIfNeeded()

        XCTAssertEqual(sut.userInterfaceIdiom(sut.view), sut.view.traitCollection.userInterfaceIdiom)
    }

    /// A view that is not in a window yet belongs to no scene, so there are no controls to clear.
    func testSceneIsNotWindowedWithoutAWindow() {
        let sut = WebViewController(server: server)
        sut.loadViewIfNeeded()

        XCTAssertFalse(sut.isSceneWindowed(sut.view))
    }

    /// The test host runs full screen, so a window on its scene fills the display and reserves nothing.
    func testSceneIsNotWindowedWhenTheWindowFillsTheScreen() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let sut = WebViewController(server: server)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = sut
        sut.loadViewIfNeeded()

        XCTAssertEqual(window.bounds.size, scene.screen.bounds.size)
        XCTAssertFalse(sut.isSceneWindowed(sut.view))
    }

    /// A scene the size of its display owns it; anything smaller in either axis shares it with other windows.
    /// UIKit keeps a scene's window at the scene's own size, so only the comparison itself is testable here.
    func testSceneIsWindowedOnlyWhenItIsSmallerThanItsScreen() {
        let screen = CGSize(width: 1032, height: 1376)

        XCTAssertFalse(WebViewController.sceneIsWindowed(windowSize: screen, screenSize: screen))
        XCTAssertTrue(
            WebViewController.sceneIsWindowed(
                windowSize: CGSize(width: 600, height: screen.height),
                screenSize: screen
            )
        )
        XCTAssertTrue(
            WebViewController.sceneIsWindowed(
                windowSize: CGSize(width: screen.width, height: 700),
                screenSize: screen
            )
        )
    }

    /// A point of rounding is not a window: the comparison has to tolerate it.
    func testSceneIsNotWindowedWhenTheSizesOnlyDifferByRounding() {
        XCTAssertFalse(
            WebViewController.sceneIsWindowed(
                windowSize: CGSize(width: 1032, height: 1375.5),
                screenSize: CGSize(width: 1032, height: 1376)
            )
        )
    }

    /// Full screen hides the status bar without handing its room to a strip the web content cannot reach.
    func testWebViewIsEdgeToEdgeInFullScreenWhenTheStatusBarIsHidden() {
        let sut = makeSUT(idiom: .pad, isWindowed: false)
        sut.cornerAdaptedSafeAreaTop = { _ in 24 }

        layOut(sut)

        XCTAssertEqual(sut.windowControlsTopInset, 0)
        XCTAssertEqual(sut.webViewTopConstraint?.constant, 0)
        XCTAssertEqual(sut.webView.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.isHidden, true)
    }

    /// The frontend's Assist button is drawn in the web view, so the zoom anchor has to follow it down.
    func testAssistZoomAnchorFollowsTheWebViewBelowTheWindowControls() {
        let sut = makeSUT(idiom: .pad)
        sut.cornerAdaptedSafeAreaTop = { _ in 44 }

        layOut(sut)

        XCTAssertEqual(sut.assistZoomAnchorView?.frame.minY, 44 + AssistZoomAnchorView.topInset)
    }

    /// Twice over: the first pass moves the web view, the second lays the moved views out.
    private func layOut(_ sut: WebViewController) {
        sut.view.layoutIfNeeded()
        sut.view.layoutIfNeeded()
    }

    private func makeSUT(idiom: UIUserInterfaceIdiom = .phone, isWindowed: Bool = true) -> WebViewController {
        let sut = WebViewController(server: server)
        sut.userInterfaceIdiom = { _ in idiom }
        sut.isSceneWindowed = { _ in isWindowed }
        // `viewDidLoad` builds `webView`, the status-bar view, and the constraints the inset moves.
        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(x: 0, y: 0, width: 820, height: 1180)
        return sut
    }
}
