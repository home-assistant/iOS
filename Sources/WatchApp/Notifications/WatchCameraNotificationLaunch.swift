import Foundation
import Shared

/// Routes a tapped camera notification to the watch's camera screen.
///
/// The long-look already shows the camera's stream, so opening the app from it should land on that
/// camera instead of the home screen. `ExtensionDelegate` records the tapped camera here and posts
/// `launchNotification`: `WatchHomeView` opens it right away when it is already on screen, and
/// consumes `pending` on appear for a cold launch — the notification fires before the view exists.
enum WatchCameraNotificationLaunch {
    static let launchNotification: Notification.Name = .init("watch-camera-notification-launch")

    /// The camera waiting to be opened, kept until a home screen takes it.
    private(set) static var pending: MagicItem?

    /// Records the tapped camera and asks a visible home screen to open it.
    static func request(entityId: String, serverId: String) {
        pending = MagicItem(id: entityId, serverId: serverId, type: .entity)
        NotificationCenter.default.post(name: launchNotification, object: nil)
    }

    /// Takes the pending camera, clearing it so a tap opens the screen exactly once.
    static func consumePending() -> MagicItem? {
        defer { pending = nil }
        return pending
    }
}
