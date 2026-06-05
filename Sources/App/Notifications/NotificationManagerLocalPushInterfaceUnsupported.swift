import HAKit
import Shared

class NotificationManagerLocalPushInterfaceDisallowed: NotificationManagerLocalPushInterface {
    func status(for server: Server) -> NotificationManagerLocalPushStatus {
        .unsupported
    }

    func addObserver(
        for server: Server,
        handler: @escaping (NotificationManagerLocalPushStatus) -> Void
    ) -> HACancellable {
        HANoopCancellable()
    }

    func retryLocalPush(for server: Server?, reason: LocalPushRetryReason) {}

    func scheduleAppOpenLocalPushRetries() {}
}
