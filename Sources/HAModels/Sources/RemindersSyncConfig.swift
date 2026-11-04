import Foundation
import GRDB

/// A user-configured pairing between an Apple Reminders list and a Home Assistant todo list.
/// Pure, extension-safe model (Foundation + GRDB only); the `Current.database()`-backed queries
/// live in an extension in the `Shared` module.
public struct RemindersSyncConfig: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable, Sendable {
    public static let databaseTableName = GRDBDatabaseTable.remindersSyncConfig.rawValue

    public var id: String
    public var serverId: String
    /// The Home Assistant todo entity, e.g. `todo.shopping_list`.
    public var todoEntityId: String
    /// Display name of the todo entity, captured at configuration time.
    public var todoEntityName: String
    /// `EKCalendar.calendarIdentifier` of the Reminders list.
    public var reminderListId: String
    /// Display name of the Reminders list, captured at configuration time so the row can still be
    /// rendered when Reminders access is revoked or the list is deleted.
    public var reminderListName: String
    public var direction: RemindersSyncDirection
    public var lastSyncDate: Date?

    public init(
        id: String,
        serverId: String,
        todoEntityId: String,
        todoEntityName: String,
        reminderListId: String,
        reminderListName: String,
        direction: RemindersSyncDirection,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.todoEntityId = todoEntityId
        self.todoEntityName = todoEntityName
        self.reminderListId = reminderListId
        self.reminderListName = reminderListName
        self.direction = direction
        self.lastSyncDate = lastSyncDate
    }
}
