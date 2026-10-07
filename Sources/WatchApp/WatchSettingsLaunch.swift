import Foundation

/// Bridges the "Open app settings" App Intent to the watch's settings sheet.
enum WatchSettingsLaunch {
    static let launchNotification: Notification.Name = .init("watch-settings-launch")

    /// Set when the intent runs before the UI is ready to present settings. `WatchHomeView`
    /// consumes this on appear so a cold launch still opens settings (the launch notification
    /// would otherwise fire before the view subscribes to it).
    static var pendingLaunch = false

    /// Asks the app to show its settings, whether or not the UI is already on screen.
    ///
    /// App Intents can run `perform()` off the main thread, and `NotificationCenter` delivers
    /// synchronously on the posting thread — which would land `WatchHomeView`'s SwiftUI state
    /// mutation off-main. Hop first so both the latch and the delivery happen on the main thread.
    static func request() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { request() }
            return
        }
        pendingLaunch = true
        NotificationCenter.default.post(name: launchNotification, object: nil)
    }
}
