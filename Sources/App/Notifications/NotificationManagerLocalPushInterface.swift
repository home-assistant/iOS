import HAKit
import Shared

enum NotificationManagerLocalPushStatus {
    case allowed(LocalPushManager.State)
    case disabled
    case unsupported
}

protocol NotificationManagerLocalPushInterface {
    func status(for server: Server) -> NotificationManagerLocalPushStatus
    func addObserver(for server: Server, handler: @escaping (NotificationManagerLocalPushStatus) -> Void)
        -> HACancellable
}
