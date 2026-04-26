import Combine
import Foundation
import Shared
import SwiftUI
import UIKit

// MARK: - Kiosk Mode Observer Protocol

/// Protocol for observing kiosk mode changes
/// Implement this protocol and register with KioskModeManager to receive updates
public protocol KioskModeObserver: AnyObject {
    /// Called when kiosk mode is enabled or disabled
    func kioskModeDidChange(isActive: Bool)

    /// Called when kiosk settings change
    func kioskSettingsDidChange(_ settings: KioskSettings)

    /// Called when screen state changes (on/dimmed/screensaver/off)
    func kioskScreenStateDidChange(_ state: ScreenState)

    /// Called when pixel shift should be applied (for OLED burn-in prevention)
    func kioskPixelShiftDidTrigger(amount: CGFloat)
}

/// Default implementations make all methods optional
public extension KioskModeObserver {
    func kioskModeDidChange(isActive: Bool) {}
    func kioskSettingsDidChange(_ settings: KioskSettings) {}
    func kioskScreenStateDidChange(_ state: ScreenState) {}
    func kioskPixelShiftDidTrigger(amount: CGFloat) {}
}

// MARK: - Kiosk Mode Manager

/// Central manager for kiosk mode functionality
/// Coordinates screen state, screensaver, brightness control, and WebViewController integration
@MainActor
public final class KioskModeManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = KioskModeManager()

    // MARK: - Published State

    /// Current kiosk settings (persisted)
    @Published public private(set) var settings: KioskSettings {
        didSet {
            saveSettings()
            settingsDidChange(from: oldValue, to: settings)
        }
    }

    /// Whether kiosk mode is currently active
    @Published public private(set) var isKioskModeActive: Bool = false

    /// Current screen state
    @Published public private(set) var screenState: ScreenState = .on

    /// Current screensaver mode (when active)
    @Published public private(set) var activeScreensaverMode: ScreensaverMode?

    /// Current brightness level (0.0 - 1.0)
    @Published public private(set) var currentBrightness: Float = 0.8

    /// App state (active or background)
    @Published public private(set) var appState: AppState = .active

    /// Last wake source
    @Published public private(set) var lastWakeSource: String = "launch"

    /// Last user activity timestamp
    @Published public private(set) var lastActivityTime: Date = Current.date()

    /// Pixel shift trigger counter - observe this in SwiftUI to trigger pixel shift
    @Published public private(set) var pixelShiftTrigger: Int = 0

    // MARK: - WebViewController Integration

    weak var webViewController: WebViewControllerProtocol?
    private var screensaverController: KioskScreensaverViewController?
    private var secretExitGestureController: KioskSecretExitGestureViewController?

    // MARK: - Private Properties

    private var idleTimer: Timer?
    private var pixelShiftTimer: Timer?
    private var originalBrightness: Float?
    private var preScreensaverBrightness: CGFloat?
    private var isIdleTimerPaused = false
    private var saveDebounceTimer: Timer?

    /// Weak wrapper for observers to avoid retain cycles
    private class WeakObserver {
        weak var observer: KioskModeObserver?
        init(_ observer: KioskModeObserver) {
            self.observer = observer
        }
    }

    /// Registered observers
    private var observers: [WeakObserver] = []

    // MARK: - Observer Management

    /// Register an observer to receive kiosk mode updates
    public func addObserver(_ observer: KioskModeObserver) {
        // Clean up any nil references while adding
        observers.removeAll { $0.observer == nil }

        // Check if already registered
        guard !observers.contains(where: { $0.observer === observer }) else { return }

        observers.append(WeakObserver(observer))
    }

    /// Unregister an observer
    public func removeObserver(_ observer: KioskModeObserver) {
        observers.removeAll { $0.observer === observer || $0.observer == nil }
    }

    /// Remove observers whose weak references have become nil
    private func pruneNilObservers() {
        observers.removeAll { $0.observer == nil }
    }

    /// Notify all observers of kiosk mode change
    private func notifyObserversOfModeChange() {
        pruneNilObservers()
        observers.forEach { $0.observer?.kioskModeDidChange(isActive: isKioskModeActive) }
    }

    /// Notify all observers of settings change
    private func notifyObserversOfSettingsChange() {
        pruneNilObservers()
        observers.forEach { $0.observer?.kioskSettingsDidChange(settings) }
    }

    /// Notify all observers of screen state change
    private func notifyObserversOfScreenStateChange() {
        pruneNilObservers()
        observers.forEach { $0.observer?.kioskScreenStateDidChange(screenState) }
    }

    /// Notify all observers of pixel shift
    private func notifyObserversOfPixelShift() {
        pruneNilObservers()
        let amount = settings.pixelShiftAmount
        observers.forEach { $0.observer?.kioskPixelShiftDidTrigger(amount: amount) }
    }

    // MARK: - Initialization

    private init() {
        self.settings = Self.loadSettings()
        setupAppLifecycleObservers()
        Current.Log.info("KioskModeManager initialized")
    }

    deinit {
        idleTimer?.invalidate()
        pixelShiftTimer?.invalidate()
        saveDebounceTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - WebViewController Setup

    /// Setup kiosk mode integration with the WebViewController
    /// Call this from WebViewController.viewDidLoad
    func setup(using webViewController: WebViewControllerProtocol) {
        self.webViewController = webViewController

        guard let viewController = webViewController as? UIViewController else { return }

        // Setup secret exit gesture overlay (always available when kiosk mode is active)
        setupSecretExitGesture(in: viewController)

        // Apply initial state if already in kiosk mode
        if isKioskModeActive {
            updateKioskModeLockdown(enabled: true)
        }
    }

    // MARK: - Status Bar & Home Indicator

    /// Whether kiosk mode wants the status bar hidden
    var prefersStatusBarHidden: Bool {
        isKioskModeActive && settings.hideStatusBar
    }

    /// Whether kiosk mode wants the home indicator hidden
    var prefersHomeIndicatorAutoHidden: Bool {
        isKioskModeActive
    }

    // MARK: - Public Methods

    /// Enable kiosk mode
    public func enableKioskMode() {
        guard !isKioskModeActive else { return }

        Current.Log.info("Enabling kiosk mode")
        isKioskModeActive = true

        // Persist enabled state so it survives app restart
        if !settings.isKioskModeEnabled {
            var updated = settings
            updated.isKioskModeEnabled = true
            settings = updated
        }

        // Store original brightness to restore later
        originalBrightness = Float(Current.screenBrightness())

        // Prevent iOS from auto-locking the screen
        if settings.preventAutoLock {
            Current.application?().isIdleTimerDisabled = true
            Current.Log.info("Screen auto-lock disabled")
        }

        // Apply brightness
        applyBrightness()
        startIdleTimer()

        updateKioskModeLockdown(enabled: true)
        notifyObserversOfModeChange()

        // Start camera detection if enabled
        #if !targetEnvironment(macCatalyst)
        startCameraDetection()
        #endif
    }

    /// Disable kiosk mode
    public func disableKioskMode() {
        guard isKioskModeActive else { return }

        Current.Log.info("Disabling kiosk mode")
        isKioskModeActive = false

        // Persist disabled state
        if settings.isKioskModeEnabled {
            var updated = settings
            updated.isKioskModeEnabled = false
            settings = updated
        }

        // Restore original brightness
        if let original = originalBrightness {
            Current.setScreenBrightness(CGFloat(original))
        }

        // Re-enable iOS auto-lock if kiosk mode had disabled it
        if settings.preventAutoLock {
            Current.application?().isIdleTimerDisabled = false
            Current.Log.info("Screen auto-lock restored")
        }

        // Stop timers
        stopIdleTimer()
        stopPixelShiftTimer()

        // Hide screensaver if active
        hideScreensaver(source: "kiosk_disabled")

        updateKioskModeLockdown(enabled: false)

        // Stop camera detection
        #if !targetEnvironment(macCatalyst)
        stopCameraDetection()
        #endif

        notifyObserversOfModeChange()
    }

    /// Update settings
    public func updateSettings(_ newSettings: KioskSettings) {
        settings = newSettings
    }

    /// Update a single setting using a closure
    public func updateSettings(_ update: (inout KioskSettings) -> Void) {
        var newSettings = settings
        update(&newSettings)
        settings = newSettings
    }

    /// Record user activity (touch, etc.)
    public func recordActivity(source: String = "touch") {
        lastActivityTime = Current.date()
        lastWakeSource = source

        // Reset idle timer
        if isKioskModeActive {
            startIdleTimer()
        }

        // If screensaver is active, wake on touch
        if screenState != .on, source == "touch" {
            wakeScreen(source: source)
        }
    }

    /// Pause the idle timer (e.g., when settings view is open)
    public func pauseIdleTimer() {
        isIdleTimerPaused = true
        stopIdleTimer()
        Current.Log.verbose("Idle timer paused")
    }

    /// Resume the idle timer
    public func resumeIdleTimer() {
        isIdleTimerPaused = false
        if isKioskModeActive {
            startIdleTimer()
        }
        Current.Log.verbose("Idle timer resumed")
    }

    // MARK: - Screen Control

    /// Wake the screen (exit screensaver, restore brightness)
    public func wakeScreen(source: String) {
        guard screenState != .on else { return }

        Current.Log.info("Waking screen from source: \(source)")
        lastWakeSource = source
        lastActivityTime = Current.date()

        hideScreensaver(source: source)

        // Restore brightness: use managed level if enabled, otherwise restore pre-screensaver level
        if settings.brightnessControlEnabled {
            applyBrightness()
        } else if let savedBrightness = preScreensaverBrightness {
            Current.setScreenBrightness(savedBrightness)
        }
        preScreensaverBrightness = nil

        screenState = .on
        notifyObserversOfScreenStateChange()

        startIdleTimer()
    }

    /// Put screen to sleep (start screensaver)
    public func sleepScreen(mode: ScreensaverMode? = nil) {
        let screensaverMode = mode ?? settings.screensaverMode

        Current.Log.info("Sleeping screen with mode: \(screensaverMode)")
        stopIdleTimer()

        showScreensaver(mode: screensaverMode)
    }

    /// Set brightness level (0-100)
    public func setBrightness(_ level: Int) {
        let clampedLevel = max(0, min(100, level))
        let brightness = Float(clampedLevel) / 100.0

        Current.Log.info("Setting brightness to \(clampedLevel)%")
        currentBrightness = brightness
        Current.setScreenBrightness(CGFloat(brightness))
    }

    /// Refresh current page
    public func refresh() {
        Current.Log.info("Refreshing current page")
        webViewController?.refresh()
    }

    /// Called when app returns to foreground
    public func appDidBecomeActive() {
        appState = .active
    }

    /// Called when app enters background
    public func appDidEnterBackground() {
        appState = .background
    }

    // MARK: - Screensaver State

    private func showScreensaver(mode: ScreensaverMode) {
        activeScreensaverMode = mode

        // Save current brightness so wakeScreen can restore it
        preScreensaverBrightness = Current.screenBrightness()

        switch mode {
        case .blank:
            screenState = .off
            Current.setScreenBrightness(0)

        case .dim:
            screenState = .dimmed
            Current.setScreenBrightness(CGFloat(settings.screensaverDimLevel))

        case .clock:
            screenState = .screensaver
            if settings.screensaverDimLevel < currentBrightness {
                Current.setScreenBrightness(CGFloat(settings.screensaverDimLevel))
            }
        }

        if settings.pixelShiftEnabled {
            startPixelShiftTimer()
        }

        presentScreensaverViewController(mode: mode)
        notifyObserversOfScreenStateChange()
    }

    private func hideScreensaver(source: String) {
        guard activeScreensaverMode != nil else { return }

        Current.Log.info("Hiding screensaver (source: \(source))")
        activeScreensaverMode = nil
        stopPixelShiftTimer()

        dismissScreensaverViewController()
    }

    // MARK: - Screensaver View Controller

    private func presentScreensaverViewController(mode: ScreensaverMode) {
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

        controller.loadViewIfNeeded()
        controller.configure(mode: mode)
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        parentVC.present(controller, animated: true)
    }

    private func dismissScreensaverViewController() {
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
            let shouldHide = enabled && settings.hideStatusBar
            statusBarView.isHidden = shouldHide
        }
    }

    // MARK: - Settings UI

    private func showKioskSettings() {
        guard webViewController != nil else { return }

        // Dismiss screensaver first if it's showing (settings should appear over WebView)
        if let screensaver = screensaverController {
            screensaver.dismiss(animated: false) { [weak self] in
                self?.screensaverController = nil
                self?.presentSettingsModal()
            }
        } else {
            presentSettingsModal()
        }
    }

    private func presentSettingsModal() {
        Current.Log.info("Showing kiosk settings")

        let settingsView = KioskSettingsView(onDismiss: { [weak self] in
            guard let webVC = self?.webViewController as? UIViewController else { return }
            webVC.dismiss(animated: true) { [weak self] in
                self?.refreshStatusBarAppearance()
            }
        })
        let hostingController = UIHostingController(rootView: settingsView)
        let navController = UINavigationController(rootViewController: hostingController)
        webViewController?.presentOverlayController(controller: navController, animated: true)
    }

    /// Force a complete status bar appearance refresh after modal dismissal
    private func refreshStatusBarAppearance() {
        guard let viewController = webViewController as? WebViewController else { return }
        viewController.navigationController?.setNeedsStatusBarAppearanceUpdate()
        viewController.setNeedsStatusBarAppearanceUpdate()
        viewController.navigationController?.setNeedsUpdateOfHomeIndicatorAutoHidden()
        viewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    // MARK: - Idle Timer

    private func startIdleTimer() {
        stopIdleTimer()

        // Don't start if paused (e.g., settings view is open)
        guard !isIdleTimerPaused else { return }
        guard settings.screensaverEnabled else { return }

        let timeout = settings.screensaverTimeout
        guard timeout > 0 else { return }

        idleTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleIdleTimeout()
            }
        }

        Current.Log.verbose("Started idle timer: \(Int(timeout))s")
    }

    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func handleIdleTimeout() {
        Current.Log.info("Idle timeout reached")
        sleepScreen()
    }

    // MARK: - Brightness

    private func applyBrightness() {
        guard settings.brightnessControlEnabled else { return }

        currentBrightness = settings.manualBrightness
        Current.setScreenBrightness(CGFloat(settings.manualBrightness))
    }

    // MARK: - Pixel Shift Timer

    private func startPixelShiftTimer() {
        stopPixelShiftTimer()

        let interval = settings.pixelShiftInterval
        guard interval > 0 else { return }

        pixelShiftTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.triggerPixelShift()
            }
        }
    }

    private func stopPixelShiftTimer() {
        pixelShiftTimer?.invalidate()
        pixelShiftTimer = nil
    }

    private func triggerPixelShift() {
        pixelShiftTrigger += 1
        notifyObserversOfPixelShift()
    }

    // MARK: - Camera Detection

    private func startCameraDetection() {
        let cameraManager = KioskCameraDetectionManager.shared

        cameraManager.onMotionDetected = { [weak self] in
            guard let self, settings.wakeOnCameraMotion else { return }
            wakeScreen(source: "camera_motion")
        }

        cameraManager.start()
    }

    private func stopCameraDetection() {
        let cameraManager = KioskCameraDetectionManager.shared
        cameraManager.onMotionDetected = nil
        cameraManager.stop()
    }

    private func restartCameraDetection() {
        stopCameraDetection()
        startCameraDetection()
    }

    // MARK: - Settings Persistence

    private static func loadSettings() -> KioskSettings {
        KioskSettingsRecord.settings()
    }

    private func saveSettings() {
        // Debounce database writes to avoid rapid persistence during slider drags
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                KioskSettingsRecord.save(settings)
            }
        }
    }

    private func settingsDidChange(from oldValue: KioskSettings, to newValue: KioskSettings) {
        guard isKioskModeActive else {
            notifyObserversOfSettingsChange()
            return
        }

        // Reapply brightness if setting changed
        if oldValue.manualBrightness != newValue.manualBrightness {
            applyBrightness()
        }

        // Restart idle timer if timeout changed
        if oldValue.screensaverTimeout != newValue.screensaverTimeout,
           screenState == .on {
            startIdleTimer()
        }

        // Apply preventAutoLock changes immediately
        if oldValue.preventAutoLock != newValue.preventAutoLock {
            Current.application?().isIdleTimerDisabled = newValue.preventAutoLock
        }

        // Apply screensaver enabled/disabled changes immediately
        if oldValue.screensaverEnabled != newValue.screensaverEnabled {
            if newValue.screensaverEnabled {
                if screenState == .on {
                    startIdleTimer()
                }
            } else {
                stopIdleTimer()
            }
        }

        // Restart camera detection only when detector configuration changes.
        // wakeOnCameraMotion is read at fire time by the closure, so toggling it
        // doesn't require tearing down the capture session.
        #if !targetEnvironment(macCatalyst)
        if oldValue.cameraMotionEnabled != newValue.cameraMotionEnabled
            || oldValue.cameraMotionSensitivity != newValue.cameraMotionSensitivity {
            restartCameraDetection()
        }
        #endif

        updateKioskModeLockdown(enabled: true)
        notifyObserversOfSettingsChange()
    }

    // MARK: - App Lifecycle Observers

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func handleAppDidBecomeActive() {
        appDidBecomeActive()
    }

    @objc private func handleAppDidEnterBackground() {
        appDidEnterBackground()
    }
}
