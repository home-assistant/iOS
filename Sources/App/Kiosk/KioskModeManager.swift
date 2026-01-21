import Combine
import Foundation
import Shared
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

/// Central singleton managing kiosk mode functionality
/// Coordinates screen state, screensaver, and brightness control
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

    /// Current dashboard URL/path
    @Published public private(set) var currentDashboard: String = ""

    /// App state (active or background)
    @Published public private(set) var appState: AppState = .active

    /// Last wake source
    @Published public private(set) var lastWakeSource: String = "launch"

    /// Last user activity timestamp
    @Published public private(set) var lastActivityTime: Date = .init()

    /// Whether connected to Home Assistant
    @Published public private(set) var isConnectedToHA: Bool = false

    /// Pixel shift trigger counter - observe this in SwiftUI to trigger pixel shift
    /// Increments each time pixel shift should occur
    @Published public private(set) var pixelShiftTrigger: Int = 0

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var idleTimer: Timer?
    private var brightnessTimer: Timer?
    private var pixelShiftTimer: Timer?
    private var originalBrightness: Float?
    private var isIdleTimerPaused = false

    /// Weak wrapper for observers to avoid retain cycles
    private class WeakObserver {
        weak var observer: KioskModeObserver?
        init(_ observer: KioskModeObserver) {
            self.observer = observer
        }
    }

    /// Registered observers
    private var observers: [WeakObserver] = []

    // MARK: - Callbacks

    /// Called when kiosk mode wants to navigate to a URL
    public var onNavigate: ((String) -> Void)?

    /// Called when kiosk mode wants to refresh the current page
    public var onRefresh: (() -> Void)?

    /// Called when screensaver should be shown
    public var onShowScreensaver: ((ScreensaverMode) -> Void)?

    /// Called when screensaver should be hidden
    public var onHideScreensaver: (() -> Void)?

    /// Called when kiosk mode is enabled/disabled (for UI lockdown)
    public var onKioskModeChange: ((Bool) -> Void)?

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

    /// Notify all observers of kiosk mode change
    private func notifyObserversOfModeChange() {
        observers.forEach { $0.observer?.kioskModeDidChange(isActive: isKioskModeActive) }
    }

    /// Notify all observers of settings change
    private func notifyObserversOfSettingsChange() {
        observers.forEach { $0.observer?.kioskSettingsDidChange(settings) }
    }

    /// Notify all observers of screen state change
    private func notifyObserversOfScreenStateChange() {
        observers.forEach { $0.observer?.kioskScreenStateDidChange(screenState) }
    }

    /// Notify all observers of pixel shift
    private func notifyObserversOfPixelShift() {
        let amount = settings.pixelShiftAmount
        observers.forEach { $0.observer?.kioskPixelShiftDidTrigger(amount: amount) }
    }

    // MARK: - Initialization

    private init() {
        self.settings = Self.loadSettings()
        setupObservers()
        Current.Log.info("KioskModeManager initialized")
    }

    deinit {
        idleTimer?.invalidate()
        brightnessTimer?.invalidate()
        pixelShiftTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Enable kiosk mode
    public func enableKioskMode() {
        guard !isKioskModeActive else { return }

        Current.Log.info("Enabling kiosk mode")
        isKioskModeActive = true

        // Store original brightness to restore later
        originalBrightness = Float(UIScreen.main.brightness)

        // Prevent iOS from auto-locking the screen
        if settings.preventAutoLock {
            UIApplication.shared.isIdleTimerDisabled = true
            Current.Log.info("Screen auto-lock disabled")
        }

        // Apply settings
        applyBrightnessSchedule()
        startIdleTimer()

        onKioskModeChange?(true)
        notifyObserversOfModeChange()
    }

    /// Disable kiosk mode
    public func disableKioskMode() {
        guard isKioskModeActive else { return }

        Current.Log.info("Disabling kiosk mode")
        isKioskModeActive = false

        // Restore original brightness
        if let original = originalBrightness {
            UIScreen.main.brightness = CGFloat(original)
        }

        // Re-enable iOS auto-lock
        UIApplication.shared.isIdleTimerDisabled = false
        Current.Log.info("Screen auto-lock restored")

        // Stop timers
        stopIdleTimer()
        stopBrightnessTimer()
        stopPixelShiftTimer()

        // Hide screensaver if active
        hideScreensaver(source: "kiosk_disabled")

        onKioskModeChange?(false)
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

    /// Record user activity (touch, motion, etc.)
    public func recordActivity(source: String = "touch") {
        lastActivityTime = Date()
        lastWakeSource = source

        // Reset idle timer
        if isKioskModeActive {
            startIdleTimer()
        }

        // If screensaver is active and this is a wake trigger, hide it
        if screenState != .on, shouldWakeForSource(source) {
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

    /// Set current dashboard URL
    public func setCurrentDashboard(_ url: String) {
        currentDashboard = url
    }

    /// Set HA connection status
    public func setConnectionStatus(_ connected: Bool) {
        isConnectedToHA = connected
    }

    // MARK: - Screen Control

    /// Wake the screen (exit screensaver, restore brightness)
    public func wakeScreen(source: String) {
        guard screenState != .on else { return }

        Current.Log.info("Waking screen from source: \(source)")
        lastWakeSource = source
        lastActivityTime = Date()

        hideScreensaver(source: source)
        applyBrightnessSchedule()

        screenState = .on
        notifyObserversOfScreenStateChange()

        // Refresh if configured
        if settings.refreshOnWake {
            onRefresh?()
        }

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
        UIScreen.main.brightness = CGFloat(brightness)
    }

    /// Navigate to a URL/path
    public func navigate(to path: String) {
        Current.Log.info("Navigating to: \(path)")
        currentDashboard = path

        // Apply kiosk parameter if enabled
        var finalPath = path
        if settings.appendHACSKioskParameter, !path.contains("kiosk") {
            if path.contains("?") {
                finalPath = "\(path)&kiosk"
            } else {
                finalPath = "\(path)?kiosk"
            }
        }

        onNavigate?(finalPath)
        recordActivity(source: "navigate")
    }

    /// Refresh current page
    public func refresh() {
        Current.Log.info("Refreshing current page")
        onRefresh?()
        recordActivity(source: "refresh")
    }

    /// Called when app returns to foreground
    public func appDidBecomeActive() {
        appState = .active

        // Refresh if needed
        if isKioskModeActive, settings.refreshOnWake {
            onRefresh?()
        }
    }

    /// Called when app enters background
    public func appDidEnterBackground() {
        appState = .background
    }

    // MARK: - Screensaver

    private func showScreensaver(mode: ScreensaverMode) {
        activeScreensaverMode = mode

        let dimLevel = screensaverDimLevel()

        switch mode {
        case .blank:
            screenState = .off
            UIScreen.main.brightness = 0

        case .dim:
            screenState = .dimmed
            UIScreen.main.brightness = CGFloat(dimLevel)

        case .clock, .clockWithEntities, .photos, .photosWithClock, .customURL:
            screenState = .screensaver
            if dimLevel < currentBrightness {
                UIScreen.main.brightness = CGFloat(dimLevel)
            }
        }

        if settings.pixelShiftEnabled {
            startPixelShiftTimer()
        }

        onShowScreensaver?(mode)
        notifyObserversOfScreenStateChange()
    }

    private func hideScreensaver(source: String) {
        guard activeScreensaverMode != nil else { return }

        Current.Log.info("Hiding screensaver (source: \(source))")
        activeScreensaverMode = nil
        stopPixelShiftTimer()

        onHideScreensaver?()
    }

    /// Returns the appropriate screensaver dim level based on schedule settings
    private func screensaverDimLevel() -> Float {
        guard settings.screensaverBrightnessScheduleEnabled else {
            return settings.screensaverDimLevel
        }

        return isNightTime() ? settings.screensaverNightDimLevel : settings.screensaverDayDimLevel
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

    // MARK: - Brightness Schedule

    private func applyBrightnessSchedule() {
        guard settings.brightnessControlEnabled else { return }

        let brightness: Float
        if settings.brightnessScheduleEnabled {
            brightness = isNightTime() ? settings.nightBrightness : settings.dayBrightness
        } else {
            brightness = settings.manualBrightness
        }

        currentBrightness = brightness
        UIScreen.main.brightness = CGFloat(brightness)

        // Schedule next brightness change if schedule is enabled
        if settings.brightnessScheduleEnabled {
            scheduleBrightnessUpdate()
        }
    }

    private func scheduleBrightnessUpdate() {
        stopBrightnessTimer()

        // Check every minute for schedule changes
        brightnessTimer = Timer.scheduledTimer(
            withTimeInterval: KioskConstants.Timing.scheduleCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyBrightnessSchedule()
            }
        }
    }

    private func stopBrightnessTimer() {
        brightnessTimer?.invalidate()
        brightnessTimer = nil
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

    // MARK: - Time Utilities

    private func isNightTime() -> Bool {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let currentTime = TimeOfDay(hour: now.hour ?? 0, minute: now.minute ?? 0)

        let dayStart = settings.dayStartTime
        let nightStart = settings.nightStartTime

        // If day starts before night in 24h time (normal case: day 07:00, night 22:00)
        if dayStart.isBefore(nightStart) {
            // Night time is: before day start OR at/after night start
            return currentTime.isBefore(dayStart) || !currentTime.isBefore(nightStart)
        } else {
            // If night starts before day in 24h time (e.g., night 02:00, day 06:00)
            // This handles edge cases where "night" represents early morning hours
            return !currentTime.isBefore(nightStart) && currentTime.isBefore(dayStart)
        }
    }

    // MARK: - Wake Source

    private func shouldWakeForSource(_ source: String) -> Bool {
        switch source {
        case "touch":
            return settings.wakeOnTouch
        case "motion", "presence":
            return settings.wakeOnCameraMotion || settings.wakeOnCameraPresence
        default:
            return true
        }
    }

    // MARK: - Settings Persistence

    private static func loadSettings() -> KioskSettings {
        KioskSettingsRecord.loadSettings()
    }

    private func saveSettings() {
        KioskSettingsRecord.saveSettings(settings)
    }

    private func settingsDidChange(from oldValue: KioskSettings, to newValue: KioskSettings) {
        // Handle kiosk mode toggle
        if oldValue.isKioskModeEnabled != newValue.isKioskModeEnabled {
            if newValue.isKioskModeEnabled {
                enableKioskMode()
            } else {
                disableKioskMode()
            }
        }

        // Reapply brightness if schedule settings changed
        if oldValue.brightnessScheduleEnabled != newValue.brightnessScheduleEnabled ||
            oldValue.dayBrightness != newValue.dayBrightness ||
            oldValue.nightBrightness != newValue.nightBrightness ||
            oldValue.manualBrightness != newValue.manualBrightness {
            if isKioskModeActive {
                applyBrightnessSchedule()
            }
        }

        // Restart idle timer if timeout changed
        if oldValue.screensaverTimeout != newValue.screensaverTimeout {
            if isKioskModeActive, screenState == .on {
                startIdleTimer()
            }
        }

        notifyObserversOfSettingsChange()
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observe app lifecycle
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
