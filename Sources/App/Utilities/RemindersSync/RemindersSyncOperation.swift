import Foundation

/// One step of a sync produced by `RemindersSyncPlanner` and applied by `RemindersSyncManager`.
/// Items are referenced by their Home Assistant `uid` and/or `EKReminder.calendarItemIdentifier`;
/// the executor resolves them against the fetched state.
enum RemindersSyncOperation: Equatable {
    /// Create a reminder from the Home Assistant item and link them.
    case createReminder(todoItemUid: String)
    /// Create a Home Assistant item from the reminder; the link is established after re-fetching
    /// the list, since `todo.add_item` doesn't return the new item's `uid`.
    case createTodoItem(reminderId: String)
    /// Overwrite the reminder with the Home Assistant item's state.
    case updateReminder(todoItemUid: String, reminderId: String)
    /// Overwrite the Home Assistant item with the reminder's state.
    case updateTodoItem(todoItemUid: String, reminderId: String)
    /// Delete the reminder and the link.
    case deleteReminder(todoItemUid: String, reminderId: String)
    /// Delete the Home Assistant item and the link.
    case deleteTodoItem(todoItemUid: String, reminderId: String)
    /// Store (or refresh) a link between two already-matching or newly matched items.
    case adoptLink(todoItemUid: String, reminderId: String)
    /// Remove a link whose items no longer exist on either side.
    case deleteLink(todoItemUid: String)
}
