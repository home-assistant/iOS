import AVFoundation
import AVFAudio
import Combine
import Foundation
import HAKit
import PromiseKit
import Shared
import UIKit

// MARK: - Kiosk Mode Manager

/// Central singleton managing all kiosk functionality
/// Coordinates screen state, screensaver, brightness, entity triggers, and HA communication
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

    /// App state (active, away, background)
    @Published public private(set) var appState: AppState = .active

    /// Last wake source
    @Published public private(set) var lastWakeSource: String = "launch"

    /// Last user activity timestamp
    @Published public private(set) var lastActivityTime: Date = Date()

    /// Whether connected to Home Assistant
    @Published public private(set) var isConnectedToHA: Bool = false

    /// Device orientation
    @Published public private(set) var currentOrientation: OrientationLock = .current

    /// Tamper detected (unexpected orientation change)
    @Published public private(set) var tamperDetected: Bool = false

    /// Launched app name (when away)
    @Published public private(set) var launchedAppName: String?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var idleTimer: Timer?
    private var refreshTimer: Timer?
    private var brightnessTimer: Timer?
    private var pixelShiftTimer: Timer?

    private var entitySubscriptions: [HACancellable] = []
    private var haConnection: HAConnection?

    private var originalBrightness: Float?

    // Audio playback
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: - Callbacks

    /// Called when kiosk mode wants to navigate to a URL
    public var onNavigate: ((String) -> Void)?

    /// Called when kiosk mode wants to refresh the current page
    public var onRefresh: (() -> Void)?

    /// Called when screensaver should be shown
    public var onShowScreensaver: ((ScreensaverMode) -> Void)?

    /// Called when screensaver should be hidden
    public var onHideScreensaver: (() -> Void)?

    /// Called when status overlay visibility changes
    public var onStatusOverlayChange: ((Bool) -> Void)?

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
        // Clean up timers
        idleTimer?.invalidate()
        refreshTimer?.invalidate()
        brightnessTimer?.invalidate()
        pixelShiftTimer?.invalidate()

        // Clean up cancellables
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // Clean up entity subscriptions
        entitySubscriptions.forEach { $0.cancel() }
        entitySubscriptions.removeAll()

        // Remove notification observers
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

        // Apply settings
        applyBrightnessSchedule()
        startIdleTimer()
        startRefreshTimer()
        subscribeToEntityTriggers()
        startCameraDetection()

        onKioskModeChange?(true)
        NotificationCenter.default.post(name: Self.kioskModeDidChangeNotification, object: nil)

        reportSensorUpdate()
    }

    /// Disable kiosk mode (requires PIN if configured)
    public func disableKioskMode() {
        guard isKioskModeActive else { return }

        Current.Log.info("Disabling kiosk mode")
        isKioskModeActive = false

        // Restore original brightness
        if let original = originalBrightness {
            UIScreen.main.brightness = CGFloat(original)
        }

        // Stop timers
        stopIdleTimer()
        stopRefreshTimer()
        stopBrightnessTimer()
        unsubscribeFromEntityTriggers()
        stopCameraDetection()

        // Hide screensaver if active
        hideScreensaver(source: "kiosk_disabled")

        onKioskModeChange?(false)
        NotificationCenter.default.post(name: Self.kioskModeDidChangeNotification, object: nil)

        reportSensorUpdate()
    }

    /// Validate PIN for exiting kiosk mode
    public func validatePIN(_ pin: String) -> Bool {
        guard !settings.exitPIN.isEmpty else { return true }
        return pin == settings.exitPIN
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
        if screenState != .on && shouldWakeForSource(source) {
            wakeScreen(source: source)
        }
    }

    /// Set current dashboard URL
    public func setCurrentDashboard(_ url: String) {
        currentDashboard = url
        reportSensorUpdate()
    }

    /// Set HA connection status
    public func setConnectionStatus(_ connected: Bool) {
        isConnectedToHA = connected
        reportSensorUpdate()
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
        reportSensorUpdate()
    }

    /// Put screen to sleep (start screensaver)
    public func sleepScreen(mode: ScreensaverMode? = nil) {
        let screensaverMode = mode ?? settings.screensaverMode

        Current.Log.info("Sleeping screen with mode: \(screensaverMode)")
        stopIdleTimer()

        showScreensaver(mode: screensaverMode)
        reportSensorUpdate()
    }

    /// Set brightness level (0-100)
    public func setBrightness(_ level: Int) {
        let clampedLevel = max(0, min(100, level))
        let brightness = Float(clampedLevel) / 100.0

        Current.Log.info("Setting brightness to \(clampedLevel)%")
        currentBrightness = brightness
        UIScreen.main.brightness = CGFloat(brightness)

        reportSensorUpdate()
    }

    /// Navigate to a URL/path
    public func navigate(to path: String) {
        Current.Log.info("Navigating to: \(path)")
        currentDashboard = path

        // Apply kiosk parameter if enabled
        var finalPath = path
        if settings.appendKioskParameter && !path.contains("kiosk") {
            if path.contains("?") {
                finalPath = "\(path)&kiosk"
            } else {
                finalPath = "\(path)?kiosk"
            }
        }

        onNavigate?(finalPath)
        recordActivity(source: "navigate")
        reportSensorUpdate()
    }

    /// Refresh current page
    public func refresh() {
        Current.Log.info("Refreshing current page")
        onRefresh?()
        recordActivity(source: "refresh")
    }

    /// Launch external app
    public func launchApp(scheme: String, name: String? = nil) {
        // Create a temporary shortcut if name provided
        let shortcut: AppShortcut? = name.map {
            AppShortcut(name: $0, urlScheme: scheme)
        }

        // Delegate to AppLauncherManager
        let success = AppLauncherManager.shared.launchApp(urlScheme: scheme, shortcut: shortcut)

        if success {
            // Sync state from AppLauncherManager
            syncAppLauncherState()
        }
    }

    /// Sync app state from AppLauncherManager
    private func syncAppLauncherState() {
        let launcher = AppLauncherManager.shared
        appState = launcher.appState
        launchedAppName = launcher.launchedApp?.name
        reportSensorUpdate()
    }

    /// Called when app returns to foreground
    public func appDidBecomeActive() {
        // AppLauncherManager handles the return logic
        AppLauncherManager.shared.handleReturn()

        // Sync state
        syncAppLauncherState()

        // Refresh if needed and was away
        if settings.refreshOnWake && appState == .active {
            onRefresh?()
        }
    }

    /// Called when app enters background
    public func appDidEnterBackground() {
        // Only set background if not launching an app (which sets away)
        if appState == .active {
            appState = .background
            reportSensorUpdate()
        }
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

    /// Returns the appropriate screensaver dim level based on schedule settings
    private func screensaverDimLevel() -> Float {
        if settings.screensaverBrightnessScheduleEnabled {
            return isNightTime() ? settings.screensaverNightDimLevel : settings.screensaverDayDimLevel
        }
        return settings.screensaverDimLevel
    }

    private func hideScreensaver(source: String) {
        guard activeScreensaverMode != nil else { return }

        activeScreensaverMode = nil
        stopPixelShiftTimer()

        onHideScreensaver?()
    }

    // MARK: - Brightness Control

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

        // Schedule next brightness change if using schedule
        if settings.brightnessScheduleEnabled {
            scheduleBrightnessChange()
        }
    }

    private func isNightTime() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = TimeOfDay(hour: hour, minute: minute)

        // Night time if current time is after nightStart OR before dayStart
        if settings.nightStartTime.isBefore(settings.dayStartTime) {
            // Normal case: night is e.g., 22:00 - 07:00
            return !currentTime.isBefore(settings.nightStartTime) || currentTime.isBefore(settings.dayStartTime)
        } else {
            // Edge case: night is e.g., 07:00 - 22:00 (inverted)
            return !currentTime.isBefore(settings.nightStartTime) && currentTime.isBefore(settings.dayStartTime)
        }
    }

    private func scheduleBrightnessChange() {
        stopBrightnessTimer()

        let now = Date()
        let calendar = Calendar.current

        // Find next transition time
        var nextTransition: Date?
        let dayComponents = settings.dayStartTime.asDateComponents
        let nightComponents = settings.nightStartTime.asDateComponents

        if let dayTime = calendar.nextDate(after: now, matching: dayComponents, matchingPolicy: .nextTime),
           let nightTime = calendar.nextDate(after: now, matching: nightComponents, matchingPolicy: .nextTime) {
            nextTransition = dayTime < nightTime ? dayTime : nightTime
        }

        guard let transitionTime = nextTransition else { return }

        let interval = transitionTime.timeIntervalSince(now)
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.applyBrightnessSchedule()
        }
    }

    private func stopBrightnessTimer() {
        brightnessTimer?.invalidate()
        brightnessTimer = nil
    }

    // MARK: - Timers

    private func startIdleTimer() {
        stopIdleTimer()

        guard settings.screensaverEnabled, settings.screensaverTimeout > 0 else { return }

        idleTimer = Timer.scheduledTimer(withTimeInterval: settings.screensaverTimeout, repeats: false) { [weak self] _ in
            guard let self, self.isKioskModeActive else { return }

            // Don't sleep if presence is currently detected (safeguard)
            if self.settings.wakeOnCameraPresence && CameraDetectionManager.shared.presenceDetected {
                Current.Log.info("Idle timer fired but presence detected - restarting timer")
                self.startIdleTimer()
                return
            }

            self.sleepScreen()
        }
    }

    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func startRefreshTimer() {
        stopRefreshTimer()

        guard settings.autoRefreshInterval > 0 else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: settings.autoRefreshInterval, repeats: true) { [weak self] _ in
            guard let self, self.isKioskModeActive, self.screenState == .on else { return }
            self.refresh()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // Note: Return reminder timer is now handled by AppLauncherManager

    private func startPixelShiftTimer() {
        stopPixelShiftTimer()

        guard settings.pixelShiftEnabled, settings.pixelShiftInterval > 0 else { return }

        pixelShiftTimer = Timer.scheduledTimer(
            withTimeInterval: settings.pixelShiftInterval,
            repeats: true
        ) { [weak self] _ in
            // Post notification for screensaver view to handle
            NotificationCenter.default.post(name: .kioskPixelShiftTick, object: nil)
        }
    }

    private func stopPixelShiftTimer() {
        pixelShiftTimer?.invalidate()
        pixelShiftTimer = nil
    }

    // MARK: - Camera Detection

    private func startCameraDetection() {
        let cameraManager = CameraDetectionManager.shared

        // Configure callbacks for wake/activity
        cameraManager.onMotionDetected = { [weak self] in
            self?.recordActivity(source: "camera_motion")
        }

        cameraManager.onPresenceChanged = { [weak self] detected in
            if detected {
                self?.recordActivity(source: "camera_presence")
            }
        }

        // Start detection (will request permission if needed)
        cameraManager.start()

        // If camera features are enabled but not authorized, request authorization
        if settings.cameraMotionEnabled || settings.cameraPresenceEnabled || settings.cameraFaceDetectionEnabled {
            if cameraManager.authorizationStatus == .notDetermined {
                Task {
                    _ = await cameraManager.requestAuthorization()
                }
            }
        }
    }

    private func stopCameraDetection() {
        // Clear callbacks to prevent memory leaks and stale references
        let cameraManager = CameraDetectionManager.shared
        cameraManager.onMotionDetected = nil
        cameraManager.onPresenceChanged = nil
        cameraManager.stop()
    }

    // MARK: - Entity Triggers

    private func subscribeToEntityTriggers() {
        unsubscribeFromEntityTriggers()

        // Get the HA connection
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            Current.Log.warning("No HA server available for entity subscriptions")
            return
        }

        // Collect all entities we need to watch
        var entitiesToWatch = Set<String>()

        for trigger in settings.wakeEntities where trigger.enabled {
            entitiesToWatch.insert(trigger.entityId)
        }

        for trigger in settings.sleepEntities where trigger.enabled {
            entitiesToWatch.insert(trigger.entityId)
        }

        for trigger in settings.entityTriggers where trigger.enabled {
            entitiesToWatch.insert(trigger.entityId)
        }

        guard !entitiesToWatch.isEmpty else { return }

        Current.Log.info("Subscribing to \(entitiesToWatch.count) entities for triggers")

        // Subscribe to state changes via HAKit
        // Note: This is a simplified version - actual implementation would use HAKit's subscription API
        for entityId in entitiesToWatch {
            let cancellable = api.connection.caches.states().subscribe { [weak self] _, states in
                guard let state = states.all.first(where: { $0.entityId == entityId }) else { return }
                // Dispatch to main actor for UI updates
                Task { @MainActor [weak self] in
                    self?.handleEntityStateChange(entityId: entityId, state: state.state)
                }
            }
            entitySubscriptions.append(cancellable)
        }
    }

    private func unsubscribeFromEntityTriggers() {
        entitySubscriptions.forEach { $0.cancel() }
        entitySubscriptions.removeAll()
    }

    private func handleEntityStateChange(entityId: String, state: String) {
        // Check wake triggers
        for trigger in settings.wakeEntities where trigger.enabled && trigger.entityId == entityId {
            if state == trigger.triggerState {
                DispatchQueue.main.asyncAfter(deadline: .now() + trigger.delay) { [weak self] in
                    self?.wakeScreen(source: "entity:\(entityId)")
                }
            }
        }

        // Check sleep triggers
        for trigger in settings.sleepEntities where trigger.enabled && trigger.entityId == entityId {
            if state == trigger.triggerState {
                DispatchQueue.main.asyncAfter(deadline: .now() + trigger.delay) { [weak self] in
                    self?.sleepScreen()
                }
            }
        }

        // Check action triggers
        for trigger in settings.entityTriggers where trigger.enabled && trigger.entityId == entityId {
            if state == trigger.triggerState {
                executeAction(trigger.action, duration: trigger.duration)
            }
        }
    }

    private func executeAction(_ action: TriggerAction, duration: TimeInterval?) {
        switch action {
        case .navigate(let url):
            navigate(to: url)

            // If duration is set, navigate back after timeout
            if let duration {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                    if let primary = self?.settings.primaryDashboardURL, !primary.isEmpty {
                        self?.navigate(to: primary)
                    }
                }
            }

        case .setBrightness(let level):
            setBrightness(Int(level * 100))

        case .startScreensaver(let mode):
            sleepScreen(mode: mode)

        case .stopScreensaver:
            wakeScreen(source: "trigger")

        case .refresh:
            refresh()

        case .playSound(let url):
            playSound(from: url)

        case .tts(let message):
            speakText(message)
        }
    }

    // MARK: - Audio Playback

    private func playSound(from urlString: String) {
        guard let url = URL(string: urlString) else {
            Current.Log.warning("Invalid sound URL: \(urlString)")
            return
        }

        Current.Log.info("Playing sound: \(urlString)")

        // Handle local vs remote URLs
        if url.isFileURL {
            playLocalSound(url: url)
        } else {
            Task {
                await playRemoteSound(url: url)
            }
        }
    }

    private func playLocalSound(url: URL) {
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            Current.Log.error("Failed to play local sound: \(error.localizedDescription)")
        }
    }

    private func playRemoteSound(url: URL) async {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Validate HTTP response
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                Current.Log.error("Failed to download sound: HTTP \(httpResponse.statusCode)")
                return
            }

            guard !data.isEmpty else {
                Current.Log.error("Downloaded sound data is empty")
                return
            }

            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            Current.Log.error("Failed to download/play sound: \(error.localizedDescription)")
        }
    }

    // MARK: - Text-to-Speech

    private func speakText(_ text: String) {
        guard !text.isEmpty else {
            Current.Log.warning("TTS: Empty text provided")
            return
        }

        Current.Log.info("TTS: \(text)")

        // Stop any current speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = settings.ttsVolume

        // Use device language or fallback to English
        if let preferredLanguage = Locale.preferredLanguages.first {
            utterance.voice = AVSpeechSynthesisVoice(language: preferredLanguage)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        speechSynthesizer.speak(utterance)
    }

    // MARK: - Settings Persistence

    private static let settingsKey = "kiosk_mode_settings"

    /// App group UserDefaults for settings persistence across app updates
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard
    }

    private static func loadSettings() -> KioskSettings {
        // First try app group (new location)
        if let data = defaults.data(forKey: settingsKey) {
            do {
                return try JSONDecoder().decode(KioskSettings.self, from: data)
            } catch {
                Current.Log.error("Failed to decode kiosk settings: \(error). Using defaults.")
                return KioskSettings()
            }
        }

        // Migration: check standard UserDefaults (old location) and migrate if found
        if let legacyData = UserDefaults.standard.data(forKey: settingsKey) {
            Current.Log.info("Migrating kiosk settings from standard UserDefaults to app group")
            do {
                let settings = try JSONDecoder().decode(KioskSettings.self, from: legacyData)
                // Save to new location
                defaults.set(legacyData, forKey: settingsKey)
                // Remove from old location
                UserDefaults.standard.removeObject(forKey: settingsKey)
                return settings
            } catch {
                Current.Log.error("Failed to migrate kiosk settings: \(error). Using defaults.")
            }
        }

        return KioskSettings()
    }

    public func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            Self.defaults.set(data, forKey: Self.settingsKey)
        } catch {
            Current.Log.error("Failed to encode kiosk settings: \(error)")
        }
    }

    /// Update a single setting using a key path
    /// - Parameters:
    ///   - keyPath: The key path to the setting to update
    ///   - value: The new value
    public func updateSetting<T>(_ keyPath: WritableKeyPath<KioskSettings, T>, to value: T) {
        var newSettings = settings
        newSettings[keyPath: keyPath] = value
        settings = newSettings
    }

    private func settingsDidChange(from oldSettings: KioskSettings, to newSettings: KioskSettings) {
        // Re-apply relevant settings if kiosk mode is active
        if isKioskModeActive {
            if oldSettings.brightnessControlEnabled != newSettings.brightnessControlEnabled ||
               oldSettings.brightnessScheduleEnabled != newSettings.brightnessScheduleEnabled ||
               oldSettings.dayBrightness != newSettings.dayBrightness ||
               oldSettings.nightBrightness != newSettings.nightBrightness ||
               oldSettings.manualBrightness != newSettings.manualBrightness {
                applyBrightnessSchedule()
            }

            if oldSettings.autoRefreshInterval != newSettings.autoRefreshInterval {
                startRefreshTimer()
            }

            if oldSettings.screensaverEnabled != newSettings.screensaverEnabled ||
               oldSettings.screensaverTimeout != newSettings.screensaverTimeout {
                startIdleTimer()
            }

            // Re-subscribe if entity triggers changed
            if oldSettings.wakeEntities != newSettings.wakeEntities ||
               oldSettings.sleepEntities != newSettings.sleepEntities ||
               oldSettings.entityTriggers != newSettings.entityTriggers {
                subscribeToEntityTriggers()
            }
        }

        NotificationCenter.default.post(name: Self.settingsDidChangeNotification, object: nil)
    }

    // MARK: - Observers

    private func setupObservers() {
        // App lifecycle
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

        // Orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        // Network changes (for refresh on reconnect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkChange),
            name: .init("NetworkReachabilityDidChange"),
            object: nil
        )
    }

    @objc private func handleAppDidBecomeActive() {
        appDidBecomeActive()
    }

    @objc private func handleAppDidEnterBackground() {
        appDidEnterBackground()
    }

    @objc private func handleOrientationChange() {
        let orientation = UIDevice.current.orientation
        let newLock: OrientationLock

        switch orientation {
        case .portrait: newLock = .portrait
        case .portraitUpsideDown: newLock = .portraitUpsideDown
        case .landscapeLeft: newLock = .landscapeLeft
        case .landscapeRight: newLock = .landscapeRight
        default: return
        }

        // Check for tamper
        if settings.tamperDetectionEnabled && currentOrientation != .current && currentOrientation != newLock {
            tamperDetected = true
            reportSensorUpdate()
        }

        currentOrientation = newLock
    }

    @objc private func handleNetworkChange() {
        if isKioskModeActive && settings.refreshOnNetworkReconnect {
            // Small delay to let connection stabilize
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.refresh()
            }
        }
    }

    // MARK: - Sensor Reporting

    private func reportSensorUpdate() {
        // Trigger sensor update to HA
        // This will be picked up by the KioskSensorProvider
        NotificationCenter.default.post(name: .kioskSensorUpdate, object: nil)
    }

    // MARK: - Helpers

    private func shouldWakeForSource(_ source: String) -> Bool {
        switch source {
        case "touch":
            return settings.wakeOnTouch
        case "motion", "camera_motion":
            return settings.cameraMotionEnabled && settings.wakeOnCameraMotion
        case "camera_presence", "camera_face":
            return settings.cameraPresenceEnabled && settings.wakeOnCameraPresence
        case _ where source.starts(with: "entity:"):
            return true // Entity triggers always wake
        case "command":
            return true // Commands always wake
        default:
            return true
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let kioskSensorUpdate = Notification.Name("KioskSensorUpdate")
    static let kioskPixelShiftTick = Notification.Name("KioskPixelShiftTick")
}
