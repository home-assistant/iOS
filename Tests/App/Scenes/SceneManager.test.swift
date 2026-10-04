@testable import HomeAssistant
import PromiseKit
@testable import Shared
import UIKit
import XCTest

@MainActor
final class SceneManagerTests: XCTestCase {
    func testOpenSourceMessagesMentionTheURL() {
        XCTAssertEqual(
            OpenSource.notification.message(with: "/lovelace/0"),
            L10n.Alerts.OpenUrlFromNotification.message("/lovelace/0")
        )
        XCTAssertEqual(
            OpenSource.deeplink.message(with: "/lovelace/0"),
            L10n.Alerts.OpenUrlFromDeepLink.message("/lovelace/0")
        )
        XCTAssertNotEqual(OpenSource.notification.message(with: "/a"), OpenSource.deeplink.message(with: "/a"))
    }

    func testServerSelectPromptKeepsTheURLOutOfTheSentence() {
        let notification = OpenSource.notification.serverSelectPrompt(with: "/lovelace/0")
        XCTAssertEqual(notification.message, L10n.Alerts.OpenUrlFromNotification.selectServer)
        XCTAssertEqual(notification.link, "/lovelace/0")

        let deeplink = OpenSource.deeplink.serverSelectPrompt(with: "/config")
        XCTAssertEqual(deeplink.message, L10n.Alerts.OpenUrlFromDeepLink.selectServer)
        XCTAssertEqual(deeplink.link, "/config")
    }

    func testCoordinatorConveniencesForwardToTheFullRequirements() {
        let coordinator = MockAppCoordinator()
        let server = ServerFixture.standard

        coordinator.present(UIViewController())
        coordinator.showSettings()
        coordinator.selectServer(prompt: nil) { _ in }
        coordinator.open(from: .deeplink, server: server, urlString: "/a", isComingFromAppIntent: false)
        coordinator.open(
            from: .notification,
            server: server,
            urlString: "/b",
            skipConfirm: true,
            isComingFromAppIntent: true
        )
        coordinator.openSelectingServer(
            from: .deeplink,
            urlString: "/c",
            skipConfirm: false,
            isComingFromAppIntent: false
        )

        XCTAssertEqual(coordinator.presentedViewControllers.count, 1)
        XCTAssertTrue(coordinator.showSettingsCalled)
        XCTAssertFalse(coordinator.showSettingsPushedOntoNavigationStack)
        XCTAssertEqual(coordinator.selectServerCallCount, 1)
        XCTAssertFalse(coordinator.selectServerZoomedFromStandBy)
        XCTAssertEqual(coordinator.openedDeeplinks.map(\.urlString), ["/a", "/b"])
        XCTAssertEqual(coordinator.openedDeeplinksSelectingServer, ["/c"])
    }

    func testWebViewControllerPromiseFollowsTheLatestController() throws {
        let sut = SceneManager()
        XCTAssertFalse(sut.webViewControllerPromise.isFulfilled)

        let first = WebViewController(server: ServerFixture.standard)
        sut.setWebViewController(first)
        XCTAssertIdentical(try XCTUnwrap(sut.webViewControllerPromise.value), first)

        let second = WebViewController(server: ServerFixture.standard)
        sut.setWebViewController(second)
        XCTAssertIdentical(try XCTUnwrap(sut.webViewControllerPromise.value), second)
    }

    func testAppCoordinatorPromiseFollowsTheLatestRegistration() throws {
        let sut = SceneManager()
        XCTAssertFalse(sut.appCoordinator.isFulfilled)

        let first = MockAppCoordinator()
        sut.registerAppCoordinator(first)
        XCTAssertIdentical(try XCTUnwrap(sut.appCoordinator.value), first)

        let second = MockAppCoordinator()
        sut.registerAppCoordinator(second)
        sut.registerAppCoordinator(second)
        XCTAssertIdentical(try XCTUnwrap(sut.appCoordinator.value), second)
    }

    func testFullScreenConfirmShowsAHUDWithTheIconAndText() throws {
        let sut = SceneManager()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        sut.showFullScreenConfirm(icon: .checkIcon, text: "Done", onto: .value(window))

        for _ in 0 ..< 100 where !window.subviews.contains(where: { $0 is ProgressHUD }) {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        let hud = try XCTUnwrap(window.subviews.compactMap { $0 as? ProgressHUD }.first)
        XCTAssertEqual(hud.mode, .customView)
        XCTAssertEqual(hud.backgroundView.style, .blur)
        XCTAssertEqual(hud.label.text, "Done")
        XCTAssertNotNil(hud.customView)
        hud.removeFromSuperview()
    }
}
