import Combine
import Shared
import SwiftUI
import UIKit

// MARK: - Kiosk Mode Extension

extension WebViewController {
    /// Setup kiosk mode integration with KioskModeManager
    /// Call this from viewDidLoad
    public func setupKioskMode() {
        let manager = KioskModeManager.shared

        // Wire up callbacks from KioskModeManager
        manager.onNavigate = { [weak self] path in
            self?.navigateToKioskPath(path)
        }

        manager.onRefresh = { [weak self] in
            self?.refresh()
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

        // Observe kiosk mode and settings changes using Combine (auto-cleanup on dealloc)
        var cancellables = Set<AnyCancellable>()

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

        kioskCancellables = cancellables

        // Setup the screensaver
        setupScreensaver()

        // Setup secret exit gesture (only when not showing screensaver)
        setupSecretExitGesture()

        // Apply initial state if already in kiosk mode
        if manager.isKioskModeActive {
            updateKioskModeLockdown(enabled: true)
        }
    }

    // MARK: - Screensaver

    private func setupScreensaver() {
        let controller = KioskScreensaverViewController()
        screensaverController = controller

        // Forward the callback for showing settings
        controller.onShowSettings = { [weak self] in
            self?.showKioskSettings()
        }

        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        controller.didMove(toParent: self)
        controller.view.isHidden = true
    }

    private func setupSecretExitGesture() {
        let controller = KioskSecretExitGestureViewController()
        secretExitGestureController = controller

        controller.onShowSettings = { [weak self] in
            self?.showKioskSettings()
        }

        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        controller.didMove(toParent: self)
    }

    private func showScreensaver(mode: ScreensaverMode) {
        guard let controller = screensaverController else { return }

        Current.Log.info("Showing screensaver: \(mode.rawValue)")

        controller.view.isHidden = false
        view.bringSubviewToFront(controller.view)
        controller.show(mode: mode)
    }

    private func hideScreensaver() {
        guard let controller = screensaverController else { return }

        Current.Log.info("Hiding screensaver")
        controller.hide()

        // Delay hiding the view until the animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            controller.view.isHidden = true
        }
    }

    // MARK: - Navigation

    private func navigateToKioskPath(_ path: String) {
        Current.Log.info("Kiosk navigating to: \(path)")

        // Use the existing navigateToPath method
        navigateToPath(path: path)
    }

    // MARK: - UI Lockdown

    private func updateKioskModeLockdown(enabled: Bool) {
        // Note: Full lockdown of navigation gestures requires changes to WebViewController
        // For now, we just update status bar and home indicator visibility
        // Navigation lockdown will be added when we integrate more deeply with WebViewController

        // Update status bar and home indicator visibility
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    // MARK: - Status Bar & Home Indicator

    /// Override in WebViewController to check kiosk mode
    public var kioskPrefersStatusBarHidden: Bool {
        let manager = KioskModeManager.shared
        return manager.isKioskModeActive && manager.settings.hideStatusBar
    }

    /// Override in WebViewController to check kiosk mode
    public var kioskPrefersHomeIndicatorAutoHidden: Bool {
        KioskModeManager.shared.isKioskModeActive
    }

    // MARK: - Settings

    private func showKioskSettings() {
        Current.Log.info("Showing kiosk settings")

        // Use NavigationStack on iOS 16+ to avoid NavigationView dismissal issues
        // NavigationView in a modal can cause unexpected dismissals
        let hostingController: UIHostingController<AnyView>
        if #available(iOS 16.0, *) {
            hostingController = UIHostingController(
                rootView: AnyView(
                    NavigationStack {
                        KioskSettingsView()
                    }
                )
            )
        } else {
            hostingController = UIHostingController(
                rootView: AnyView(
                    NavigationView {
                        KioskSettingsView()
                    }
                    .navigationViewStyle(.stack)
                )
            )
        }

        hostingController.modalPresentationStyle = .pageSheet
        present(hostingController, animated: true)
    }

    // MARK: - Observers

    private func kioskModeDidChange() {
        let manager = KioskModeManager.shared
        Current.Log.info("Kiosk mode changed: \(manager.isKioskModeActive)")

        updateKioskModeLockdown(enabled: manager.isKioskModeActive)
    }

    private func kioskSettingsDidChange() {
        // Re-apply lockdown settings in case they changed
        let manager = KioskModeManager.shared
        if manager.isKioskModeActive {
            updateKioskModeLockdown(enabled: true)
        }
    }

    // MARK: - Touch Handling

    /// Call this when user touches the screen to record activity
    public func recordKioskActivity() {
        KioskModeManager.shared.recordActivity(source: "touch")
    }
}
