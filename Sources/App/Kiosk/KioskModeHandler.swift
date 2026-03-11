import Combine
import Shared
import SwiftUI
import UIKit

// MARK: - Kiosk Mode Handler

/// Handles kiosk mode integration with the WebViewController
/// Manages screensaver lifecycle, UI lockdown, and touch activity forwarding
@MainActor
final class KioskModeHandler {
    weak var webViewController: WebViewControllerProtocol?
    private let manager: KioskModeManager

    private var screensaverController: KioskScreensaverViewController?
    private var secretExitGestureController: KioskSecretExitGestureViewController?
    private var cancellables = Set<AnyCancellable>()

    init(webViewController: WebViewControllerProtocol? = nil, manager: KioskModeManager = .shared) {
        self.webViewController = webViewController
        self.manager = manager
    }

    // MARK: - Setup

    /// Setup kiosk mode integration with KioskModeManager
    /// Call this from viewDidLoad
    func setup() {
        guard let webViewController = webViewController as? WebViewController else { return }

        // Wire up callbacks from KioskModeManager
        manager.onRefresh = { [weak webViewController] in
            webViewController?.refresh()
        }

        manager.onKioskModeChange = { [weak self] enabled in
            self?.updateKioskModeLockdown(enabled: enabled)
        }

        manager.onShowScreensaver = { [weak self] mode in
            self?.showScreensaver(mode: mode)
        }

        manager.onHideScreensaver = { [weak self] in
            self?.hideScreensaver()
        }

        // Observe kiosk mode and settings changes using Combine
        manager.$isKioskModeActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.kioskModeDidChange()
            }
            .store(in: &cancellables)

        manager.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.kioskSettingsDidChange()
            }
            .store(in: &cancellables)

        // Setup secret exit gesture overlay (always available when kiosk mode is active)
        setupSecretExitGesture(in: webViewController)

        // Apply initial state if already in kiosk mode
        if manager.isKioskModeActive {
            updateKioskModeLockdown(enabled: true)
        }
    }

    // MARK: - Screensaver

    private func showScreensaver(mode: ScreensaverMode) {
        guard let parentVC = webViewController as? UIViewController else { return }

        // Dismiss any existing screensaver first
        if let existing = screensaverController {
            existing.dismiss(animated: false)
            screensaverController = nil
        }

        Current.Log.info("Showing screensaver: \(mode.rawValue)")

        let controller = KioskScreensaverViewController()
        screensaverController = controller

        controller.onShowSettings = { [weak self] in
            self?.showKioskSettings()
        }

        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        parentVC.present(controller, animated: true) {
            controller.show(mode: mode)
        }
    }

    private func hideScreensaver() {
        guard let controller = screensaverController else { return }

        Current.Log.info("Hiding screensaver")
        controller.dismiss(animated: true) { [weak self] in
            self?.screensaverController = nil
        }
    }

    // MARK: - Secret Exit Gesture

    private func setupSecretExitGesture(in parentController: UIViewController) {
        let controller = KioskSecretExitGestureViewController()
        secretExitGestureController = controller

        controller.onShowSettings = { [weak self] in
            self?.showKioskSettings()
        }

        parentController.addChild(controller)
        parentController.view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: parentController.view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: parentController.view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: parentController.view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: parentController.view.trailingAnchor),
        ])

        controller.didMove(toParent: parentController)
    }

    // MARK: - UI Lockdown

    private func updateKioskModeLockdown(enabled: Bool) {
        guard let viewController = webViewController as? WebViewController else { return }

        // Update iOS system status bar and home indicator visibility
        if let navController = viewController.navigationController {
            navController.setNeedsStatusBarAppearanceUpdate()
            navController.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
        viewController.setNeedsStatusBarAppearanceUpdate()
        viewController.setNeedsUpdateOfHomeIndicatorAutoHidden()

        // Hide/show the custom status bar background view
        if let statusBarView = viewController.statusBarView {
            let shouldHide = enabled && manager.settings.hideStatusBar
            statusBarView.isHidden = shouldHide
        }
    }

    // MARK: - Status Bar & Home Indicator

    /// Whether kiosk mode wants the status bar hidden
    var prefersStatusBarHidden: Bool {
        manager.isKioskModeActive && manager.settings.hideStatusBar
    }

    /// Whether kiosk mode wants the home indicator hidden
    var prefersHomeIndicatorAutoHidden: Bool {
        manager.isKioskModeActive
    }

    // MARK: - Settings

    private func showKioskSettings() {
        guard let viewController = webViewController as? UIViewController else { return }

        // Dismiss screensaver first if it's showing (settings should appear over WebView)
        if let screensaver = screensaverController {
            screensaver.dismiss(animated: false) { [weak self] in
                self?.screensaverController = nil
                self?.presentSettingsModal(from: viewController)
            }
        } else {
            presentSettingsModal(from: viewController)
        }
    }

    private func presentSettingsModal(from viewController: UIViewController) {
        Current.Log.info("Showing kiosk settings")

        let settingsView = KioskSettingsView(onDismiss: { [weak viewController] in
            viewController?.dismiss(animated: true) { [weak self] in
                self?.refreshStatusBarAppearance()
            }
        })
        let hostingController = UIHostingController(rootView: settingsView)
        let navController = UINavigationController(rootViewController: hostingController)
        navController.modalPresentationStyle = .pageSheet
        viewController.present(navController, animated: true)
    }

    /// Force a complete status bar appearance refresh after modal dismissal
    private func refreshStatusBarAppearance() {
        guard let viewController = webViewController as? WebViewController else { return }
        viewController.navigationController?.setNeedsStatusBarAppearanceUpdate()
        viewController.setNeedsStatusBarAppearanceUpdate()
        viewController.navigationController?.setNeedsUpdateOfHomeIndicatorAutoHidden()
        viewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    // MARK: - Observers

    private func kioskModeDidChange() {
        Current.Log.info("Kiosk mode changed: \(manager.isKioskModeActive)")
        updateKioskModeLockdown(enabled: manager.isKioskModeActive)
    }

    private func kioskSettingsDidChange() {
        if manager.isKioskModeActive {
            updateKioskModeLockdown(enabled: true)
        }
    }

    // MARK: - Touch Handling

    /// Record user touch activity to reset the screensaver idle timer
    /// Required because WKWebView consumes touch events before UIKit idle detection
    func recordActivity() {
        manager.recordActivity(source: "touch")
    }
}
