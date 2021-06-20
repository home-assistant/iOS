import HAKit
import Shared

class NotificationManagerLocalPushInterfaceDisallowed: NotificationManagerLocalPushInterface {
    var status: NotificationManagerLocalPushStatus {
        .unsupported
    }

    func addObserver(_ handler: @escaping (NotificationManagerLocalPushStatus) -> Void) -> HACancellable {
        HANoopCancellable()
    }
}
