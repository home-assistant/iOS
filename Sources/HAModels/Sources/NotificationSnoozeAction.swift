import Foundation
import GRDB

/// A user-configurable "snooze" quick action shown on notifications, identified on the wire as
/// `actionIdentifierPrefix + minutes` (e.g. `HA_SNOOZE_5`). The localized title, the
/// `UNNotificationAction` builders, and the `Current.database()`-backed queries live in extensions
/// in the `Shared` module.
public struct NotificationSnoozeAction: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable {
    public static let databaseTableName = GRDBDatabaseTable.notificationSnoozeAction.rawValue
    public static let actionIdentifierPrefix = "HA_SNOOZE_"

    public var id: String
    public var minutes: Int
    public var isEnabled: Bool
    public var sortOrder: Int

    public init(id: String = UUID().uuidString, minutes: Int, isEnabled: Bool = true, sortOrder: Int) {
        self.id = id
        self.minutes = minutes
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }

    public var actionIdentifier: String {
        Self.actionIdentifierPrefix + String(minutes)
    }

    /// Parses the snooze duration out of a notification action identifier, or nil when the
    /// identifier is not a snooze action (e.g. `HA_SNOOZE_15` → 15). Non-positive durations are
    /// rejected so the result is always a valid reschedule delay: action identifiers can come from
    /// notification payloads, and a zero or negative interval would be invalid to schedule.
    public static func minutes(fromActionIdentifier identifier: String) -> Int? {
        guard identifier.hasPrefix(actionIdentifierPrefix),
              let minutes = Int(identifier.dropFirst(actionIdentifierPrefix.count)),
              minutes > 0 else { return nil }
        return minutes
    }
}
