import Combine
import Shared
import SwiftUI
import UIKit

// MARK: - Kiosk Mode Extension

private var statusOverlayKey: UInt8 = 0
private var screensaverKey: UInt8 = 0
private var cameraOverlayKey: UInt8 = 0
private var quickLaunchKey: UInt8 = 0
private var secretExitGestureKey: UInt8 = 0
private var kioskCancellablesKey: UInt8 = 0

extension WebViewController {
    /// The camera overlay view controller
    private var cameraOverlayController: CameraOverlayViewController? {
        get { objc_getAssociatedObject(self, &cameraOverlayKey) as? CameraOverlayViewController }
        set { objc_setAssociatedObject(self, &cameraOverlayKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The quick launch panel view controller
    private var quickLaunchController: QuickLaunchViewController? {
        get { objc_getAssociatedObject(self, &quickLaunchKey) as? QuickLaunchViewController }
        set { objc_setAssociatedObject(self, &quickLaunchKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The secret exit gesture view controller
    private var secretExitGestureController: SecretExitGestureViewController? {
        get { objc_getAssociatedObject(self, &secretExitGestureKey) as? SecretExitGestureViewController }
        set { objc_setAssociatedObject(self, &secretExitGestureKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The status overlay view controller
    private var statusOverlayController: StatusOverlayViewController? {
        get { objc_getAssociatedObject(self, &statusOverlayKey) as? StatusOverlayViewController }
        set { objc_setAssociatedObject(self, &statusOverlayKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The screensaver view controller
    private var screensaverController: ScreensaverViewController? {
        get { objc_getAssociatedObject(self, &screensaverKey) as? ScreensaverViewController }
        set { objc_setAssociatedObject(self, &screensaverKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Cancellables for kiosk mode observers - auto-cleanup on dealloc
    private var kioskCancellables: Set<AnyCancellable> {
        get {
            (objc_getAssociatedObject(self, &kioskCancellablesKey) as? Set<AnyCancellable>) ?? Set()
        }
        set {
            objc_setAssociatedObject(self, &kioskCancellablesKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Setup kiosk mode integration with KioskModeManager
    /// Call this from viewDidLoad
    func setupKioskMode() {
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

        manager.onStatusOverlayChange = { [weak self] visible in
            self?.updateStatusOverlayVisibility(visible: visible)
        }

        manager.onShowScreensaver = { [weak self] mode in
            self?.showScreensaver(mode: mode)
        }

        manager.onHideScreensaver = { [weak self] in
            self?.hideScreensaver()
        }

        // Observe kiosk mode and settings changes using Combine (auto-cleanup on dealloc)
        var cancellables = Set<AnyCancellable>()

        NotificationCenter.default.publisher(for: KioskModeManager.kioskModeDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.kioskModeDidChange()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: KioskModeManager.settingsDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.kioskSettingsDidChange()
            }
            .store(in: &cancellables)

        kioskCancellables = cancellables

        // Setup the status overlay and screensaver
        setupStatusOverlay()
        setupScreensaver()
        setupCameraOverlay()
        setupQuickLaunchPanel()
        setupSecretExitGesture()

        // Setup dashboard and entity trigger managers
        setupDashboardManager()
        setupEntityTriggerManager()
        setupCameraTakeoverManager()

        // Apply initial state if already in kiosk mode
        if manager.isKioskModeActive {
            updateKioskModeLockdown(enabled: true)
        }

        // Report current dashboard URL
        if let url = webView?.url?.absoluteString {
            manager.setCurrentDashboard(url)
        }

        // Start managers if in kiosk mode
        if manager.isKioskModeActive {
            DashboardManager.shared.start()
            EntityTriggerManager.shared.start()
            CameraDetectionManager.shared.start()
            if manager.settings.ambientAudioDetectionEnabled {
                AmbientAudioDetector.shared.start()
            }
        }
    }

    // MARK: - Status Overlay

    private func setupStatusOverlay() {
        let overlayController = StatusOverlayViewController()
        statusOverlayController = overlayController

        addChild(overlayController)
        view.addSubview(overlayController.view)
        overlayController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            overlayController.view.topAnchor.constraint(equalTo: view.topAnchor),
            overlayController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        overlayController.didMove(toParent: self)

        // Initially hidden
        let manager = KioskModeManager.shared
        let shouldShow = manager.isKioskModeActive && manager.settings.statusOverlayEnabled
        overlayController.view.alpha = shouldShow ? 1 : 0
    }

    private func updateStatusOverlayVisibility(visible: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.statusOverlayController?.view.alpha = visible ? 1 : 0
        }
    }

    // MARK: - Screensaver

    private func setupScreensaver() {
        let controller = ScreensaverViewController()
        screensaverController = controller

        // Wire up secret exit gesture from screensaver
        controller.onShowSettings = { [weak self] in
            self?.showKioskSettingsSheet()
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

        // Initially hidden
        controller.view.alpha = 0
        controller.view.isHidden = true
    }

    private func showScreensaver(mode: ScreensaverMode) {
        guard let controller = screensaverController else { return }

        Current.Log.info("Showing screensaver: \(mode.rawValue)")

        // Bring screensaver to front (but behind status overlay)
        if let statusView = statusOverlayController?.view {
            view.insertSubview(controller.view, belowSubview: statusView)
        } else {
            view.bringSubviewToFront(controller.view)
        }

        controller.view.isHidden = false
        controller.show(mode: mode)
    }

    private func hideScreensaver() {
        guard let controller = screensaverController else { return }

        Current.Log.info("Hiding screensaver")
        controller.hide()

        // Hide after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            controller.view.isHidden = true
        }
    }

    /// Navigate to a path for kiosk mode
    private func navigateToKioskPath(_ path: String) {
        // Check if it's an absolute URL or relative path
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            if let url = URL(string: path) {
                open(inline: url)
            }
        } else {
            // Relative path - append to server URL
            navigateToPath(path: path)
        }

        // Update the manager with the new dashboard
        KioskModeManager.shared.setCurrentDashboard(path)
    }

    /// Update lockdown state based on kiosk mode
    func updateKioskModeLockdown(enabled: Bool) {
        let manager = KioskModeManager.shared
        let lockNavigation = enabled && manager.settings.navigationLockdown

        // Disable/enable pull-to-refresh
        updatePullToRefresh(enabled: !lockNavigation)

        // Disable/enable edge gestures
        updateEdgeGestures(enabled: !lockNavigation)

        // Update scroll bouncing
        webView?.scrollView.bounces = !lockNavigation

        Current.Log.info("Kiosk lockdown updated: enabled=\(enabled), navigationLockdown=\(lockNavigation)")
    }

    /// Enable or disable pull-to-refresh
    private func updatePullToRefresh(enabled: Bool) {
        guard !Current.isCatalyst else { return }

        if enabled {
            // Re-add refresh control if not present
            if refreshControl.superview == nil {
                webView?.scrollView.addSubview(refreshControl)
            }
            refreshControl.isEnabled = true
        } else {
            // Remove refresh control
            refreshControl.removeFromSuperview()
            refreshControl.isEnabled = false
        }
    }

    /// Enable or disable edge pan gestures
    private func updateEdgeGestures(enabled: Bool) {
        leftEdgePanGestureRecognizer.isEnabled = enabled
        rightEdgeGestureRecognizer.isEnabled = enabled
    }

    // MARK: - Notification Handlers

    @MainActor
    private func kioskModeDidChange() {
        let manager = KioskModeManager.shared
        let enabled = manager.isKioskModeActive
        updateKioskModeLockdown(enabled: enabled)

        // Update status bar visibility
        setNeedsStatusBarAppearanceUpdate()

        // Ensure secret exit gesture is on top when kiosk mode is active
        if enabled, let gestureView = secretExitGestureController?.view {
            view.bringSubviewToFront(gestureView)
        }

        // Start or stop managers based on kiosk mode state
        if enabled {
            DashboardManager.shared.start()
            EntityTriggerManager.shared.start()
            CameraDetectionManager.shared.start()
            if manager.settings.ambientAudioDetectionEnabled {
                AmbientAudioDetector.shared.start()
            }
        } else {
            // Stop managers in reverse order of dependency
            CameraTakeoverManager.shared.dismissCamera()
            CameraOverlayManager.shared.dismiss()
            AmbientAudioDetector.shared.stop()
            CameraDetectionManager.shared.stop()
            EntityTriggerManager.shared.stop()
            DashboardManager.shared.stop()

            // Navigate back to device's default dashboard
            if let defaultURL = server.info.connection.webviewURL() {
                Current.Log.info("Kiosk mode disabled - navigating to default dashboard: \(defaultURL)")
                load(request: URLRequest(url: defaultURL))
            }
        }
    }

    @MainActor
    private func kioskSettingsDidChange() {
        // Re-apply lockdown in case navigationLockdown setting changed
        let enabled = KioskModeManager.shared.isKioskModeActive
        updateKioskModeLockdown(enabled: enabled)

        // Update status bar visibility if hideStatusBar setting changed
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - Touch Handling for Kiosk Mode

    /// Record activity when the webview receives touches
    @MainActor
    func recordKioskActivity() {
        if KioskModeManager.shared.isKioskModeActive {
            KioskModeManager.shared.recordActivity(source: "touch")

            // Notify dashboard manager of user activity (for rotation pause)
            DashboardManager.shared.userActivity()
        }
    }
}

// MARK: - UIScrollViewDelegate Extension

extension WebViewController {
    /// Call this from scrollViewWillBeginDragging
    func handleScrollViewDragging() {
        // Already on main thread from scroll view delegate
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if KioskModeManager.shared.isKioskModeActive {
                KioskModeManager.shared.recordActivity(source: "touch")
                DashboardManager.shared.userActivity()
            }
        }
    }
}

// MARK: - Dashboard Manager Integration

extension WebViewController {
    private func setupDashboardManager() {
        let dashboardManager = DashboardManager.shared

        // Handle navigation requests from dashboard manager
        dashboardManager.onNavigate = { [weak self] url in
            self?.navigateToKioskPath(url)
        }
    }
}

// MARK: - Entity Trigger Manager Integration

extension WebViewController {
    private func setupEntityTriggerManager() {
        let triggerManager = EntityTriggerManager.shared

        // Handle navigation triggers
        triggerManager.onNavigate = { [weak self] url in
            self?.navigateToKioskPath(url)
        }

        // Handle screensaver triggers
        triggerManager.onStartScreensaver = { [weak self] mode in
            let screensaverMode = mode ?? KioskModeManager.shared.settings.screensaverMode
            self?.showScreensaver(mode: screensaverMode)
        }

        triggerManager.onStopScreensaver = { [weak self] in
            self?.hideScreensaver()
        }

        // Handle brightness triggers
        triggerManager.onSetBrightness = { level in
            UIScreen.main.brightness = CGFloat(level)
        }

        // Handle refresh triggers
        triggerManager.onRefresh = { [weak self] in
            self?.refresh()
        }

        // Handle TTS triggers
        triggerManager.onTTS = { message in
            AudioManager.shared.speak(message, priority: .high)
        }
    }
}

// MARK: - Camera Overlay Integration

extension WebViewController {
    private func setupCameraOverlay() {
        let controller = CameraOverlayViewController()
        cameraOverlayController = controller

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

        // Configure expand callback
        CameraOverlayManager.shared.onExpandToFullScreen = { [weak self] stream in
            self?.showFullScreenCamera(stream: stream)
        }
    }

    private func setupCameraTakeoverManager() {
        CameraTakeoverManager.shared.onDismiss = { [weak self] in
            // Return to previous state when camera is dismissed
            Current.Log.info("Camera takeover dismissed")
        }
    }

    /// Show full-screen camera from PiP expansion or direct trigger
    func showFullScreenCamera(stream: CameraStream) {
        CameraTakeoverManager.shared.showCamera(
            stream: stream,
            from: self,
            autoDismiss: stream.autoDismissSeconds
        )
    }

    /// Show camera overlay for doorbell or security event
    func showCameraOverlay(stream: CameraStream) {
        CameraOverlayManager.shared.show(stream: stream)
    }

    /// Dismiss camera overlay
    func dismissCameraOverlay() {
        CameraOverlayManager.shared.dismiss()
    }
}

// MARK: - Quick Launch Panel Integration

extension WebViewController {
    private func setupQuickLaunchPanel() {
        let controller = QuickLaunchViewController()
        quickLaunchController = controller

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

        // Update visibility based on kiosk mode and settings
        updateQuickLaunchPanelVisibility()
    }

    private func updateQuickLaunchPanelVisibility() {
        let manager = KioskModeManager.shared
        let shouldShow = manager.isKioskModeActive && manager.settings.quickLaunchEnabled

        quickLaunchController?.view.isHidden = !shouldShow
    }
}

// MARK: - Secret Exit Gesture Integration

extension WebViewController {
    private func setupSecretExitGesture() {
        let controller = SecretExitGestureViewController()
        secretExitGestureController = controller

        // Set up the callback to show kiosk settings
        controller.onShowSettings = { [weak self] in
            self?.showKioskSettingsSheet()
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

        // Bring to front so it can receive taps
        view.bringSubviewToFront(controller.view)
    }

    /// Show the kiosk settings sheet for exiting kiosk mode
    private func showKioskSettingsSheet() {
        Current.Log.info("Secret exit gesture triggered - showing kiosk settings")

        let settingsView = NavigationView {
            KioskSettingsView()
        }

        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.modalPresentationStyle = .formSheet

        present(hostingController, animated: true)
    }
}

// MARK: - Kiosk Mode State Changes

extension WebViewController {
    @objc private func handleKioskModeEnabled() {
        DashboardManager.shared.start()
        EntityTriggerManager.shared.start()
        CameraDetectionManager.shared.start()
        if KioskModeManager.shared.settings.ambientAudioDetectionEnabled {
            AmbientAudioDetector.shared.start()
        }
    }

    @objc private func handleKioskModeDisabled() {
        DashboardManager.shared.stop()
        EntityTriggerManager.shared.stop()
        CameraDetectionManager.shared.stop()
        AmbientAudioDetector.shared.stop()
        AudioManager.shared.stopAudio()
        AudioManager.shared.stopSpeaking()
        CameraOverlayManager.shared.dismiss()
        CameraTakeoverManager.shared.dismissCamera()
    }
}
