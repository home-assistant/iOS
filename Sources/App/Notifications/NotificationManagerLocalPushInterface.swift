import Foundation
import HAKit
import Shared

enum NotificationManagerLocalPushStatus {
    case allowed(LocalPushManager.State)
    case disabled
    case unsupported
}

enum LocalPushRetryReason: Equatable {
    case appOpen
    case appOpenDelayed(seconds: TimeInterval)
    case manual
    case serverChanged

    var eventValue: String {
        switch self {
        case .appOpen:
            return "app_open"
        case let .appOpenDelayed(seconds):
            return "app_open_\(Int(seconds))s"
        case .manual:
            return "manual"
        case .serverChanged:
            return "server_changed"
        }
    }
}

protocol NotificationManagerLocalPushInterface {
    func status(for server: Server) -> NotificationManagerLocalPushStatus
    func addObserver(for server: Server, handler: @escaping (NotificationManagerLocalPushStatus) -> Void)
        -> HACancellable
    func retryLocalPush(for server: Server?, reason: LocalPushRetryReason)
    func scheduleAppOpenLocalPushRetries()
}
