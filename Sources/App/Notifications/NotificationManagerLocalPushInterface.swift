import Shared
import HAKit

enum NotificationManagerLocalPushStatus {
    case allowed(LocalPushManager.State)
    case disabled
    case unsupported
}

protocol NotificationManagerLocalPushInterface {
    var status: NotificationManagerLocalPushStatus { get }
    func addObserver(_ handler: @escaping (NotificationManagerLocalPushStatus) -> Void) -> HACancellable
}
