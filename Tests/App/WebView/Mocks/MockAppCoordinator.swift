@testable import HomeAssistant
import PromiseKit
import Shared
import UIKit

/// Test double for `AppCoordinator`, recording the presentation calls the web frontend routes through it.
final class MockAppCoordinator: AppCoordinator {
    private(set) var showSettingsCalled = false
    private(set) var showAssistSettingsCalled = false
    var onShowSettings: (() -> Void)?
    var onShowAssistSettings: (() -> Void)?

    var presentedViewController: UIViewController?
    var window: UIWindow?

    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {}
    func show(alert: ServerAlert) {}

    func showSettings() {
        showSettingsCalled = true
        onShowSettings?()
    }

    func showAssistSettings() {
        showAssistSettingsCalled = true
        onShowAssistSettings?()
    }

    func showDownloadManager(_ viewModel: DownloadManagerViewModel) {}
    func showOnboardingPermissions(server: Server, steps: [OnboardingPermissionsNavigationViewModel.StepID]) {}

    func open(server: Server) -> Guarantee<any WebFrontend> {
        Guarantee<any WebFrontend> { _ in }
    }

    func selectServer(prompt: String?, includeSettings: Bool, completion: @escaping (Server) -> Void) {}
    func presentInvitation(url: URL?) {}
    func setup() {}

    func open(
        from: OpenSource,
        server: Server,
        urlString: String,
        skipConfirm: Bool,
        avoidUnnecessaryReload: Bool,
        isComingFromAppIntent: Bool
    ) {}

    func openSelectingServer(
        from: OpenSource,
        urlString: String,
        skipConfirm: Bool,
        queryParameters: [URLQueryItem]?,
        isComingFromAppIntent: Bool
    ) {}
}
