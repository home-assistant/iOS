import Foundation

enum AssistDefaultComplication {
    static let title = "Assist"
    static let launchNotification: Notification.Name = .init("assist-detault-complication-launch")
    static let defaultComplicationId = "default-assist"

    /// Set when the app is launched from the Assist complication before the UI is ready to present it.
    /// `WatchHomeView` consumes this on appear so a cold launch still opens Assist (the launch
    /// notification would otherwise fire before the view subscribes to it).
    static var pendingLaunch = false
}
