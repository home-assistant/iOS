@testable import HomeAssistant
@testable import Shared
import SwiftUI
import XCTest

@MainActor
final class WebViewGestureHandlerTests: XCTestCase {
    func testOpenInBrowserActionAsksWebViewToOpenCurrentPageInBrowser() {
        let webView = MockWebViewController()
        let sut = makeSUT(webView: webView)

        sut.handleGestureAction(.openInBrowser)

        XCTAssertTrue(webView.openInBrowserCalled)
    }

    func testNoneActionDoesNotOpenBrowser() {
        let webView = MockWebViewController()
        let sut = makeSUT(webView: webView)

        sut.handleGestureAction(.none)

        XCTAssertFalse(webView.openInBrowserCalled)
    }

    func testCreateDeeplinkActionPresentsDeeplinkForCurrentPage() throws {
        let webView = MockWebViewController()
        webView.currentPageURL = URL(string: "https://home.local/lovelace/0")
        let sut = makeSUT(webView: webView)

        sut.handleGestureAction(.createDeeplink)

        XCTAssertTrue(webView.presentOverlayControllerCalled)
        let controller = try XCTUnwrap(webView.overlayedController)
        XCTAssertTrue(String(describing: type(of: controller)).contains("DeeplinkView"))
    }

    func testCreateDeeplinkActionWithoutCurrentPageDoesNothing() {
        let webView = MockWebViewController()
        let sut = makeSUT(webView: webView)

        sut.handleGestureAction(.createDeeplink)

        XCTAssertFalse(webView.presentOverlayControllerCalled)
    }

    func testShowSettingsActionAsksTheWebViewToOpenSettings() {
        let webView = MockWebViewController()
        let sut = makeSUT(webView: webView)

        sut.handleGestureAction(.showSettings)

        XCTAssertTrue(webView.showSettingsCalled)
        XCTAssertFalse(webView.showSettingsPushedOntoNavigationStack)
    }

    /// The gesture happened in one window, so the picker opens on that window's coordinator rather than on
    /// whichever one registered last.
    func testShowServersListActionGoesToTheCoordinatorOfTheWebViewsOwnScene() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let webView = MockWebViewController()
        webView.presentationWindow = UIWindow(windowScene: scene)
        let sceneCoordinator = MockAppCoordinator()
        sceneCoordinator.window = webView.presentationWindow
        let otherWindowCoordinator = MockAppCoordinator()
        otherWindowCoordinator.window = UIWindow()
        Current.sceneManager.registerAppCoordinator(sceneCoordinator)
        Current.sceneManager.registerAppCoordinator(otherWindowCoordinator)
        let pickerShown = expectation(description: "server picker shown")
        sceneCoordinator.onSelectServer = { pickerShown.fulfill() }

        makeSUT(webView: webView).handleGestureAction(.showServersList)

        wait(for: [pickerShown], timeout: 1)
        XCTAssertEqual(otherWindowCoordinator.selectServerCallCount, 0)
    }

    private func makeSUT(webView: MockWebViewController) -> WebViewGestureHandler {
        let sut = WebViewGestureHandler()
        sut.webView = webView
        return sut
    }
}
