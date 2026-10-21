@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// The container hosts onboarding — which runs a `NavigationStack` of its own — and the frontend without
/// adding a navigation container of its own around either. Nesting a second stack around onboarding made
/// SwiftUI force-try a comparison of their differently-typed paths and raise an unexpected error, and on
/// iOS 27.1 a navigation container around the frontend makes UIKit reserve iPhone Duo's vertical bar: an
/// 84 pt safe-area strip the frontend never fills, on the outer edge of its Split View pane.
@MainActor
final class ContainerNavigationTests: XCTestCase {
    private var previousServers: ServerManager!
    private var window: UIWindow?
    /// The presenter the hosted container is given, standing in for the one it would own per scene.
    private var presenter: AppSettingsPresenter!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        presenter = AppSettingsPresenter()
    }

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        presenter = nil
        Current.servers = previousServers
        super.tearDown()
    }

    func testOnboardingBringsTheOnlyNavigationStack() {
        Current.servers = FakeServerManager(initial: 0)

        let window = hostContainer()

        XCTAssertLessThanOrEqual(
            navigationControllerCount(under: window.rootViewController),
            1,
            "Onboarding brings its own NavigationStack; a second one around it is what crashes SwiftUI"
        )
    }

    func testFrontendIsHostedWithoutANavigationContainer() {
        Current.servers = FakeServerManager(initial: 1)

        let window = hostContainer()

        XCTAssertEqual(
            navigationControllerCount(under: window.rootViewController),
            0,
            "A navigation container around the frontend reserves iPhone Duo's vertical bar for a bar it never shows"
        )
    }

    // MARK: - Helpers

    /// Puts the real app root on screen, so the screens below it lay out exactly as they do at launch.
    private func hostContainer() -> UIWindow {
        let controller = UIHostingController(rootView: ConditionalContainerView(appSettings: presenter))
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
