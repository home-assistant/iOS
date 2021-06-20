import Shared
import HAKit

class NotificationManagerLocalPushInterfaceDisallowed: NotificationManagerLocalPushInterface {
    var status: NotificationManagerLocalPushStatus {
        .unsupported
    }

    func addObserver(_ handler: @escaping (NotificationManagerLocalPushStatus) -> Void) -> HACancellable {
        HANoopCancellable()
    }
}
