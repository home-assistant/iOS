import Combine
import Foundation
import Shared
import UIKit

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

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var idleTimer: Timer?
    private var brightnessTimer: Timer?
    private var pixelShiftTimer: Timer?
    private var originalBrightness: Float?

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

    // MARK: - Notifications

    public static let settingsDidChangeNotification = Notification.Name("KioskModeSettingsDidChange")
    public static let screenStateDidChangeNotification = Notification.Name("KioskModeScreenStateDidChange")
    public static let kioskModeDidChangeNotification = Notification.Name("KioskModeDidChange")

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

        // Update touch feedback configuration
        TouchFeedbackManager.shared.configure(from: settings)

        // Apply settings
        applyBrightnessSchedule()
        startIdleTimer()

        onKioskModeChange?(true)
        NotificationCenter.default.post(name: Self.kioskModeDidChangeNotification, object: nil)
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
        NotificationCenter.default.post(name: Self.kioskModeDidChangeNotification, object: nil)
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
        NotificationCenter.default.post(name: Self.screenStateDidChangeNotification, object: nil)

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
        NotificationCenter.default.post(name: Self.screenStateDidChangeNotification, object: nil)
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
        NotificationCenter.default.post(
            name: Notification.Name("KioskPixelShift"),
            object: nil,
            userInfo: ["amount": settings.pixelShiftAmount]
        )
    }

    // MARK: - Time Utilities

    private func isNightTime() -> Bool {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let currentTime = TimeOfDay(hour: now.hour ?? 0, minute: now.minute ?? 0)

        let dayStart = settings.dayStartTime
        let nightStart = settings.nightStartTime

        // If day starts before night (normal case: day 7am, night 10pm)
        if dayStart.isBefore(nightStart) {
            // Night time is: before day start OR after night start
            return currentTime.isBefore(dayStart) || !currentTime.isBefore(nightStart)
        } else {
            // If night starts before day (e.g., day 6am, night 11pm across midnight)
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

    private static let settingsKey = "KioskModeSettings"

    private static func loadSettings() -> KioskSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            Current.Log.info("No saved kiosk settings found, using defaults")
            return KioskSettings()
        }

        do {
            let settings = try JSONDecoder().decode(KioskSettings.self, from: data)
            Current.Log.info("Loaded kiosk settings from UserDefaults")
            return settings
        } catch {
            Current.Log.error("Failed to decode kiosk settings: \(error)")
            return KioskSettings()
        }
    }

    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
            Current.Log.verbose("Saved kiosk settings to UserDefaults")
        } catch {
            Current.Log.error("Failed to encode kiosk settings: \(error)")
        }
    }

    private func settingsDidChange(from oldValue: KioskSettings, to newValue: KioskSettings) {
        // Update touch feedback configuration
        TouchFeedbackManager.shared.configure(from: newValue)

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

        NotificationCenter.default.post(name: Self.settingsDidChangeNotification, object: nil)
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
