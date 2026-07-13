import Foundation
import GRDB
import UserNotifications

// `NotificationSnoozeAction` itself lives in the `HAModels` package; these are its localized
// title, `UNNotificationAction` builders, and database-backed helpers.
public extension NotificationSnoozeAction {
    var title: String {
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

    var action: UNNotificationAction {
        UNNotificationAction(identifier: actionIdentifier, title: title, options: [])
    }
}

extension NotificationSnoozeAction {
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
