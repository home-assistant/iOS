import Foundation
import GRDB
import UserNotifications

/// A user-configurable "snooze" quick action shown on notifications, identified on the wire as
/// `actionIdentifierPrefix + minutes` (e.g. `HA_SNOOZE_5`).
public struct NotificationSnoozeAction: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable {
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

    public var title: String {
        guard minutes >= 60 else {
            return L10n.SettingsDetails.Notifications.SnoozeActions.titleMinutes(minutes)
        }

        let hours = minutes / 60
        let remainder = minutes % 60

        switch (hours, remainder) {
        case (1, 0):
            return L10n.SettingsDetails.Notifications.SnoozeActions.titleHour
        case (_, 0):
            return L10n.SettingsDetails.Notifications.SnoozeActions.titleHours(hours)
        case (1, _):
            return L10n.SettingsDetails.Notifications.SnoozeActions.titleHourMinutes(remainder)
        default:
            return L10n.SettingsDetails.Notifications.SnoozeActions.titleHoursMinutes(hours, remainder)
        }
    }

    public var action: UNNotificationAction {
        UNNotificationAction(identifier: actionIdentifier, title: title, options: [])
    }

    static func seedDefaultsIfNeeded(database: DatabaseQueue) throws {
        let defaults = [5, 15, 60].enumerated().map { index, minutes in
            NotificationSnoozeAction(minutes: minutes, sortOrder: index)
        }
        try database.write { db in
            for action in defaults {
                try action.insert(db)
            }
        }
    }
}

public extension NotificationSnoozeAction {
    /// All configured presets, sorted for display.
    static func all() -> [NotificationSnoozeAction] {
        do {
            return try Current.database().read { db in
                try NotificationSnoozeAction
                    .order(Column(DatabaseTables.NotificationSnoozeAction.sortOrder.rawValue))
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch notification snooze actions: \(error.localizedDescription)")
            return []
        }
    }

    #if DEBUG
    static let debugTenSecondsActionIdentifier = actionIdentifierPrefix + "DEBUG_10S"

    static var debugTenSecondsAction: UNNotificationAction {
        UNNotificationAction(identifier: debugTenSecondsActionIdentifier, title: "Snooze 10s (Debug)", options: [])
    }
    #endif

    /// The `UNNotificationAction`s that should be attached to a notification, in order.
    static func enabledActions() -> [UNNotificationAction] {
        var actions = all().filter(\.isEnabled).map(\.action)
        #if DEBUG
        actions.append(debugTenSecondsAction)
        #endif
        return actions
    }

    static func save(_ action: NotificationSnoozeAction) {
        do {
            _ = try Current.database().write { db in
                try action.insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save notification snooze action: \(error.localizedDescription)")
        }
    }

    static func delete(id: String) {
        do {
            _ = try Current.database().write { db in
                try NotificationSnoozeAction.deleteOne(db, key: id)
            }
        } catch {
            Current.Log.error("Failed to delete notification snooze action: \(error.localizedDescription)")
        }
    }

    /// Persists a new sort order for all presets, matching the order of `orderedIDs`.
    static func reorder(_ orderedIDs: [String]) {
        do {
            _ = try Current.database().write { db in
                for (index, id) in orderedIDs.enumerated() {
                    try db.execute(
                        sql: """
                        UPDATE \(GRDBDatabaseTable.notificationSnoozeAction.rawValue)
                        SET \(DatabaseTables.NotificationSnoozeAction.sortOrder.rawValue) = ?
                        WHERE \(DatabaseTables.NotificationSnoozeAction.id.rawValue) = ?
                        """,
                        arguments: [index, id]
                    )
                }
            }
        } catch {
            Current.Log.error("Failed to reorder notification snooze actions: \(error.localizedDescription)")
        }
    }
}
