@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// The container hosts the frontend inside the navigation stack app Settings is pushed onto, and hosts
/// onboarding — which runs a `NavigationStack` of its own — outside it. Nesting the two made SwiftUI
/// force-try a comparison of their differently-typed paths and raise an unexpected error: on a push for
/// iOS 17 and later, and on the app's very first layout on iOS 16.
@MainActor
final class ContainerNavigationTests: XCTestCase {
    private var previousServers: ServerManager!
    private var window: UIWindow?

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        AppSettingsPresenter.shared.pushPath = NavigationPath()
    }

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        AppSettingsPresenter.shared.pushPath = NavigationPath()
        Current.servers = previousServers
        super.tearDown()
    }

    func testOnboardingIsHostedOutsideTheSettingsNavigationStack() {
        Current.servers = FakeServerManager(initial: 0)

        let window = hostContainer()

        XCTAssertLessThanOrEqual(
            navigationControllerCount(under: window.rootViewController),
            1,
            "Onboarding brings its own NavigationStack; a second one around it is what crashes SwiftUI"
        )
    }

    func testFrontendHostsSettingsPushesWithoutNestingNavigationStacks() {
        Current.servers = FakeServerManager(initial: 1)

        let window = hostContainer()

        XCTAssertLessThanOrEqual(
            navigationControllerCount(under: window.rootViewController),
            1,
            "The frontend is shown inside the one stack Settings is pushed onto"
        )

        // What the frontend's external bus asks for, and what used to crash on the way in.
        AppSettingsPresenter.shared.isPushPresented = true
        settle(window)

        XCTAssertEqual(AppSettingsPresenter.shared.pushPath.count, 1)

        // Settings pushes its own screens onto the same path, as `AppSettingsPushRoute.item`.
        AppSettingsPresenter.shared.pushPath.append(AppSettingsPushRoute.item(.help))
        settle(window)

        XCTAssertEqual(AppSettingsPresenter.shared.pushPath.count, 2)

        AppSettingsPresenter.shared.isPushPresented = false
        settle(window)

        XCTAssertTrue(AppSettingsPresenter.shared.pushPath.isEmpty)
    }

    // MARK: - Helpers

    /// Puts the real app root on screen, so the screens below it lay out exactly as they do at launch.
    private func hostContainer() -> UIWindow {
        let controller = UIHostingController(rootView: ConditionalContainerView())
        // On the host app's scene, so the window is a real one that reports appearance; a window
        // without a scene never appears, and the screens are only built once they do.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: CGSize(width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        settle(window)
        self.window = window
        return window
    }

    /// Lets SwiftUI apply the pending state change and lay the result out before it is inspected.
    private func settle(_ window: UIWindow) {
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        window.layoutIfNeeded()
    }

    private func navigationControllerCount(under controller: UIViewController?) -> Int {
        guard let controller else { return 0 }
        let own = controller is UINavigationController ? 1 : 0
        return controller.children.reduce(own) { $0 + navigationControllerCount(under: $1) }
    }
}
