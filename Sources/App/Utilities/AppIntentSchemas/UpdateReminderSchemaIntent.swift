import AppIntents
import Foundation
import Shared

/// Edits an item on a Home Assistant todo list.
///
/// `todo.update_item` replaces the fields it is given, so anything the caller left out is refilled
/// from the item as it stands. Moving an item between lists, flags, tags, URLs, recurrence and
/// location triggers have no equivalent in the `todo` domain and are ignored.
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.updateReminder)
struct UpdateReminderSchemaIntent {
    var target: ReminderSchemaEntity
    var title: String?
    var note: AttributedString?
    var tags: Set<String>?
    var urls: [URL]?
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?
    var isCompleted: Bool?
    var isFlagged: Bool?
    var list: ReminderListSchemaEntity?
    var locationTrigger: LocationTriggerSchemaEntity?

    func perform() async throws -> some ReturnsValue<ReminderSchemaEntity> {
        let api = try RemindersSchemaSupport.api(for: target.list)
        let newTitle = title ?? target.title
        let newNote = note.map(String.init) ?? target.note
        let newDue = dueDate ?? target.dueDate
        let completed = isCompleted ?? target.isCompleted
        let due = RemindersSchemaSupport.due(newDue)

        try await api.updateTodoItem(
            listId: target.list.entityId,
            itemId: target.uid,
            rename: newTitle,
            status: completed ? "completed" : "needs_action",
            description: newNote,
            dueDate: due.date,
            dueDateTime: due.dateTime
        )

        return .result(value: ReminderSchemaEntity(
            id: target.id,
            uid: target.uid,
            title: newTitle,
            list: target.list,
            dueDate: newDue,
            isCompleted: completed,
            note: newNote
        ))
    }
}
