@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

/// macOS draws its window buttons in the title bar, above everything UIKit lays out, so the offset
/// iPadOS 26's window controls need must never reach the Mac. These pin the Catalyst layout to what it
/// was before that offset existed.
@MainActor
final class WebViewControllerCatalystLayoutTests: XCTestCase {
    /// Stands in for the room Catalyst's title bar leaves at the top of the scene. Added to whatever the
    /// host window already reserves, so the assertions below read the resulting inset rather than this.
    private static let titleBarInset: CGFloat = 28

    private var previousServers: ServerManager!
    private var previousIsCatalyst: Bool!
    private var servers: FakeServerManager!
    private var server: Server!
    private var window: UIWindow!

    override func setUp() async throws {
        previousServers = Current.servers
        previousIsCatalyst = Current.isCatalyst
        servers = FakeServerManager(initial: 0)
        server = servers.addFake()
        Current.servers = servers
        Current.isCatalyst = true
    }

    override func tearDown() async throws {
        Current.servers = previousServers
        Current.isCatalyst = previousIsCatalyst
        previousServers = nil
        previousIsCatalyst = nil
        servers = nil
        server = nil
        window = nil
    }

    /// Catalyst starts the web view below the status-bar view, which fills the title bar's safe area.
    func testWebViewStartsBelowTheTitleBar() {
        let sut = makeSUT()

        layOut(sut)

        let titleBar = sut.view.safeAreaInsets.top
        XCTAssertGreaterThanOrEqual(titleBar, Self.titleBarInset)
        XCTAssertEqual(sut.webView.frame.minY, titleBar)
        XCTAssertEqual(sut.statusBarView?.frame.minY, 0)
        XCTAssertEqual(sut.statusBarView?.frame.height, titleBar)
    }

    /// The window buttons sit on it, so the strip iOS hides when it has no controls to clear stays up here.
    func testStatusBarViewStaysVisible() {
        let sut = makeSUT()

        layOut(sut)

        XCTAssertEqual(sut.statusBarView?.isHidden, false)
    }

    /// The web view already starts below the title bar, so the iPadOS offset must not stack onto it —
    /// even when the platform reports room reserved in the corners.
    func testWindowControlsInsetIsNeverApplied() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { view in view.safeAreaInsets.top + 44 }

        layOut(sut)

        XCTAssertEqual(sut.windowControlsTopInset, 0)
        XCTAssertEqual(sut.webViewTopConstraint?.constant, 0)
        XCTAssertEqual(sut.webView.frame.minY, sut.view.safeAreaInsets.top)
        XCTAssertEqual(sut.statusBarView?.isHidden, false)
    }

    /// A resize is only another layout pass, which is what applies the offset on iOS; Catalyst takes none.
    func testResizingLeavesTheWebViewWhereItIs() {
        let sut = makeSUT()
        sut.cornerAdaptedSafeAreaTop = { view in view.safeAreaInsets.top + 44 }
        layOut(sut)

        window.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        layOut(sut)

        let titleBar = sut.view.safeAreaInsets.top
        XCTAssertEqual(sut.webView.frame.minY, titleBar)
        XCTAssertEqual(sut.webView.frame.height, sut.view.bounds.height - titleBar)
    }

    /// Aligning the Assist anchor to the web view rather than the root view leaves Mac where it was: the
    /// web view starts at the root view's safe area, so on Catalyst the two spell the same position.
    func testAssistZoomAnchorSitsWhereTheRootViewSafeAreaPutIt() {
        let sut = makeSUT()

        layOut(sut)

        XCTAssertEqual(
            sut.assistZoomAnchorView?.frame.minY,
            sut.view.safeAreaInsets.top + AssistZoomAnchorView.topInset
        )
        XCTAssertEqual(
            sut.assistZoomAnchorView?.frame.maxX,
            sut.view.bounds.width - sut.view.safeAreaInsets.right - AssistZoomAnchorView.trailingInset
        )
    }

    /// Twice over, matching the iOS tests: the first pass would move the web view, the second lays it out.
    private func layOut(_ sut: WebViewController) {
        sut.view.setNeedsLayout()
        window.layoutIfNeeded()
        window.layoutIfNeeded()
    }

    /// In a window, so `additionalSafeAreaInsets` actually reaches the view: a detached controller reports
    /// no safe area at all, which would leave every inset here reading zero and assert nothing.
    private func makeSUT() -> WebViewController {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1280, height: 800))
        self.window = window

        let sut = WebViewController(server: server)
        window.rootViewController = sut
        window.makeKeyAndVisible()
        // `viewDidLoad` builds `webView`, the status-bar view, and the constraints between them.
        sut.loadViewIfNeeded()
        // No window here has a title bar, so stand one in: this is the room Catalyst leaves at the top.
        sut.additionalSafeAreaInsets = UIEdgeInsets(top: Self.titleBarInset, left: 0, bottom: 0, right: 0)
        return sut
    }
}
