import Combine
import Foundation
import Shared
import UIKit
import UserNotifications

// MARK: - App Launcher Manager

/// Manages external app launching, return timeout, and away state tracking
@MainActor
public final class AppLauncherManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = AppLauncherManager()

    // MARK: - Published State

    /// Current app state (active, away, background)
    @Published public private(set) var appState: AppState = .active

    /// Whether the app is currently "away" (another app was launched)
    @Published public private(set) var isAway: Bool = false

    /// The app that was launched (if tracking)
    @Published public private(set) var launchedApp: AppShortcut?

    /// Time when the app was launched
    @Published public private(set) var launchTime: Date?

    /// Time remaining on return timeout (if active)
    @Published public private(set) var returnTimeRemaining: TimeInterval = 0

    // MARK: - Notifications

    public static let appStateDidChangeNotification = Notification.Name("AppLauncherManager.appStateDidChange")
    public static let didReturnFromAppNotification = Notification.Name("AppLauncherManager.didReturnFromApp")

    // MARK: - Callbacks

    /// Called when return timeout expires
    public var onReturnTimeoutExpired: (() -> Void)?

    /// Called when user returns from launched app
    public var onReturnFromApp: ((AppShortcut?) -> Void)?

    // MARK: - Private

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private var returnTimer: Timer?
    private var countdownTimer: Timer?
    private var sceneObservers: [NSObjectProtocol] = []

    // MARK: - Initialization

    private init() {
        setupSceneObservers()
        requestNotificationPermission()
    }

    deinit {
        sceneObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Public Methods

    /// Launch an app by URL scheme
    public func launchApp(urlScheme: String, shortcut: AppShortcut? = nil) -> Bool {
        guard let url = URL(string: urlScheme) else {
            Current.Log.warning("Invalid URL scheme: \(urlScheme)")
            return false
        }

        return launchApp(url: url, shortcut: shortcut)
    }

    /// Launch an app by URL
    public func launchApp(url: URL, shortcut: AppShortcut? = nil) -> Bool {
        guard UIApplication.shared.canOpenURL(url) else {
            Current.Log.warning("Cannot open URL: \(url)")
            return false
        }

        Current.Log.info("Launching app: \(url.absoluteString)")

        // Record the launch
        launchedApp = shortcut
        launchTime = Date()
        isAway = true
        appState = .away

        // Start return timeout if configured
        startReturnTimeout()

        // Open the URL
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                Current.Log.warning("Failed to open URL: \(url)")
                Task { @MainActor in
                    self.cancelAwayState()
                }
            }
        }

        // Record activity
        KioskModeManager.shared.recordActivity(source: "app_launch")

        // Notify
        NotificationCenter.default.post(name: Self.appStateDidChangeNotification, object: nil)

        return true
    }

    /// Launch an app shortcut
    public func launchShortcut(_ shortcut: AppShortcut) -> Bool {
        launchApp(urlScheme: shortcut.urlScheme, shortcut: shortcut)
    }

    /// Return to HAFrame (called when app becomes active again)
    public func handleReturn() {
        guard isAway else { return }

        Current.Log.info("Returned from app: \(launchedApp?.name ?? "unknown")")

        cancelReturnTimeout()

        let returnedFromApp = launchedApp
        launchedApp = nil
        launchTime = nil
        isAway = false
        appState = .active
        returnTimeRemaining = 0

        // Notify
        onReturnFromApp?(returnedFromApp)
        NotificationCenter.default.post(
            name: Self.didReturnFromAppNotification,
            object: nil,
            userInfo: ["app": returnedFromApp as Any]
        )
        NotificationCenter.default.post(name: Self.appStateDidChangeNotification, object: nil)

        // Record activity
        KioskModeManager.shared.recordActivity(source: "app_return")
    }

    /// Cancel away state without triggering return callbacks
    public func cancelAwayState() {
        cancelReturnTimeout()
        launchedApp = nil
        launchTime = nil
        isAway = false
        appState = .active
        returnTimeRemaining = 0
    }

    /// Get all configured app shortcuts
    public var shortcuts: [AppShortcut] {
        settings.appShortcuts
    }

    /// Check if an app can be launched
    public func canLaunch(urlScheme: String) -> Bool {
        guard let url = URL(string: urlScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Get duration since app was launched
    public var awayDuration: TimeInterval? {
        guard let launchTime else { return nil }
        return Date().timeIntervalSince(launchTime)
    }

    // MARK: - Private Methods

    private func setupSceneObservers() {
        // Observe app becoming active (returning from another app)
        let activeObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSceneActivation()
        }
        sceneObservers.append(activeObserver)

        // Observe app going to background
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSceneBackground()
        }
        sceneObservers.append(backgroundObserver)

        // Observe app becoming inactive
        let inactiveObserver = NotificationCenter.default.addObserver(
            forName: UIScene.willDeactivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSceneDeactivation()
        }
        sceneObservers.append(inactiveObserver)
    }

    private func handleSceneActivation() {
        if isAway {
            handleReturn()
        } else if appState == .background {
            appState = .active
            NotificationCenter.default.post(name: Self.appStateDidChangeNotification, object: nil)
        }
    }

    private func handleSceneBackground() {
        if !isAway {
            appState = .background
            NotificationCenter.default.post(name: Self.appStateDidChangeNotification, object: nil)
        }
    }

    private func handleSceneDeactivation() {
        // This fires when the app is about to go to background
        // Don't change state here - wait for didEnterBackground
    }

    // MARK: - Return Timeout

    private func startReturnTimeout() {
        let timeout = settings.appLaunchReturnTimeout
        guard timeout > 0 else { return }

        cancelReturnTimeout()
        returnTimeRemaining = timeout

        Current.Log.info("Starting return timeout: \(Int(timeout)) seconds")

        // Countdown timer for UI updates
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.returnTimeRemaining > 0 {
                    self.returnTimeRemaining -= 1
                }
            }
        }

        // Main timeout timer
        returnTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleReturnTimeout()
            }
        }

        // Schedule local notification
        scheduleReturnNotification(timeout: timeout)
    }

    private func cancelReturnTimeout() {
        returnTimer?.invalidate()
        returnTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        returnTimeRemaining = 0

        // Cancel pending notification
        cancelReturnNotification()
    }

    private func handleReturnTimeout() {
        Current.Log.info("Return timeout expired")

        cancelReturnTimeout()
        onReturnTimeoutExpired?()

        // The notification will alert the user to return
    }

    // MARK: - Local Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Current.Log.error("Failed to request notification permission: \(error)")
            } else if granted {
                Current.Log.info("Notification permission granted for return reminders")
            }
        }
    }

    private func scheduleReturnNotification(timeout: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "HAFrame"
        content.body = "Time to return to your dashboard"
        content.sound = .default
        content.categoryIdentifier = "HAFRAME_RETURN"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeout, repeats: false)
        let request = UNNotificationRequest(
            identifier: "haframe.return.reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Current.Log.error("Failed to schedule return notification: \(error)")
            }
        }
    }

    private func cancelReturnNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["haframe.return.reminder"]
        )
    }
}

// MARK: - App Launcher Command Support

extension AppLauncherManager {
    /// Handle launch app command from HA notification
    public func handleLaunchCommand(urlScheme: String) -> Bool {
        // Find matching shortcut if exists
        let shortcut = settings.appShortcuts.first { $0.urlScheme == urlScheme }
        return launchApp(urlScheme: urlScheme, shortcut: shortcut)
    }
}

// MARK: - Sensor Attributes

extension AppLauncherManager {
    /// Sensor state for HA reporting
    public var sensorState: String {
        appState.rawValue
    }

    /// Sensor attributes for HA reporting
    public var sensorAttributes: [String: Any] {
        var attrs: [String: Any] = [
            "is_away": isAway,
        ]

        if let launchedApp {
            attrs["launched_app"] = launchedApp.name
            attrs["launched_scheme"] = launchedApp.urlScheme
        }

        if let launchTime {
            attrs["launch_time"] = ISO8601DateFormatter().string(from: launchTime)
            attrs["away_duration_seconds"] = Int(awayDuration ?? 0)
        }

        if returnTimeRemaining > 0 {
            attrs["return_timeout_remaining"] = Int(returnTimeRemaining)
        }

        return attrs
    }
}
