import Foundation

/// Bridges the "Open app settings" App Intent to the watch's settings sheet.
enum WatchSettingsLaunch {
    static let launchNotification: Notification.Name = .init("watch-settings-launch")

    /// Set when the intent runs before the UI is ready to present settings. `WatchHomeView`
    /// consumes this on appear so a cold launch still opens settings (the launch notification
    /// would otherwise fire before the view subscribes to it).
    static var pendingLaunch = false

    /// Asks the app to show its settings, whether or not the UI is already on screen.
    static func request() {
        pendingLaunch = true
        NotificationCenter.default.post(name: launchNotification, object: nil)
    }
}
