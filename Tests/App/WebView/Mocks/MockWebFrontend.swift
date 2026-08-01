@testable import HomeAssistant
import Shared
import UIKit

/// Test double for `WebFrontend`, recording what the app coordinator asks the running frontend to do.
final class MockWebFrontend: WebFrontend {
    let server: Server
    var presentationWindow: UIWindow?

    private(set) var openedInlineURLs: [URL] = []
    private(set) var openedPanelURLs: [URL] = []
    private(set) var navigateToRootCallCount = 0
    private(set) var dismissOverlayControllerCallCount = 0
    private(set) var presentedOverlayControllers: [UIViewController] = []

    var onOpen: ((URL) -> Void)?

    init(server: Server, presentationWindow: UIWindow? = nil) {
        self.server = server
        self.presentationWindow = presentationWindow
    }

    func show(alert: ServerAlert) {}

    func open(inline url: URL, avoidUnnecessaryReload: Bool) {
        openedInlineURLs.append(url)
        onOpen?(url)
    }

    func openPanel(_ url: URL) {
        openedPanelURLs.append(url)
        onOpen?(url)
    }

    func navigateToRoot() {
        navigateToRootCallCount += 1
    }

    func dismissOverlayController(animated: Bool, completion: (() -> Void)?) {
        dismissOverlayControllerCallCount += 1
        completion?()
    }

    func presentOverlayController(controller: UIViewController, animated: Bool) {
        presentedOverlayControllers.append(controller)
    }
}
