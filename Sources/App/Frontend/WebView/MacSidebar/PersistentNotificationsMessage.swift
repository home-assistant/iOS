import Foundation
import HAKit
import Shared

/// One event of the `persistent_notification/subscribe` stream: a full snapshot (`current`) or an
/// incremental change (`added`, `updated`, `removed`) keyed by notification id.
struct PersistentNotificationsMessage: HADataDecodable, Equatable {
    enum ChangeType: String {
        case current
        case added
        case updated
        case removed
    }

    var type: ChangeType
    var notificationIds: Set<String>

    init(type: ChangeType, notificationIds: Set<String>) {
        self.type = type
        self.notificationIds = notificationIds
    }

    init(data: HAData) throws {
        let rawType: String = try data.decode("type")
        guard let type = ChangeType(rawValue: rawType) else {
            throw HADataError.couldntTransform(key: "type")
        }
        self.type = type
        let notifications: [String: Any] = data.decode("notifications", fallback: [:])
        self.notificationIds = Set(notifications.keys)
    }

    func apply(to current: Set<String>) -> Set<String> {
        switch type {
        case .current:
            return notificationIds
        case .added, .updated:
            return current.union(notificationIds)
        case .removed:
            return current.subtracting(notificationIds)
        }
    }
}
