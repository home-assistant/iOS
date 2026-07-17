import Foundation
import GRDB

/// Links one Home Assistant todo item to its Apple Reminders counterpart within a
/// `RemindersSyncConfig`, remembering the item state at the last successful sync so the next sync
/// can tell which side changed. Pure, extension-safe model (Foundation + GRDB only); the
/// `Current.database()`-backed queries live in an extension in the `Shared` module.
public struct RemindersSyncItemLink: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable {
    public static let databaseTableName = GRDBDatabaseTable.remindersSyncItemLink.rawValue

    public var id: String
    public var configId: String
    /// The Home Assistant todo item `uid`.
    public var todoItemUid: String
    /// `EKCalendarItem.calendarItemIdentifier` of the paired reminder.
    public var reminderId: String
    public var lastKnownTitle: String
    public var lastKnownCompleted: Bool
    public var lastKnownNotes: String?
    /// Normalized due string: `yyyy-MM-dd` for all-day, ISO8601 with offset when a time is set.
    public var lastKnownDue: String?

    public init(
        configId: String,
        todoItemUid: String,
        reminderId: String,
        lastKnownTitle: String,
        lastKnownCompleted: Bool,
        lastKnownNotes: String?,
        lastKnownDue: String?
    ) {
        self.id = Self.id(configId: configId, todoItemUid: todoItemUid)
        self.configId = configId
        self.todoItemUid = todoItemUid
        self.reminderId = reminderId
        self.lastKnownTitle = lastKnownTitle
        self.lastKnownCompleted = lastKnownCompleted
        self.lastKnownNotes = lastKnownNotes
        self.lastKnownDue = lastKnownDue
    }

    /// Deterministic primary key so re-linking the same item replaces the previous row.
    public static func id(configId: String, todoItemUid: String) -> String {
        "\(configId)-\(todoItemUid)"
    }
}
