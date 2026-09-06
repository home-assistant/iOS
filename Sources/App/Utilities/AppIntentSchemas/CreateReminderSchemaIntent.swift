import AppIntents
import Foundation
import Shared

/// Adds an item to a Home Assistant todo list.
///
/// Flags, tags, URLs, images, location triggers, recurrence and sections have no equivalent in the
/// `todo` domain, so they are accepted to satisfy the schema and then ignored rather than being
/// folded into the note, which would put text on the list the user did not dictate.
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.createReminder)
struct CreateReminderSchemaIntent {
    var title: String
    var list: ReminderListSchemaEntity?
    var note: AttributedString?
    var isFlagged: Bool?
    var images: [IntentFile]
    var tags: Set<String>
    var urls: [URL]
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?
    var locationTrigger: LocationTriggerSchemaEntity?
    var section: ReminderSectionSchemaEntity?

    func perform() async throws -> some ReturnsValue<ReminderSchemaEntity> {
        let target = try list ?? RemindersSchemaSupport.defaultList()
        let api = try RemindersSchemaSupport.api(for: target)
        let due = RemindersSchemaSupport.due(dueDate)

        try await api.addTodoItem(
            listId: target.entityId,
            summary: title,
            description: note.map(String.init),
            dueDate: due.date,
            dueDateTime: due.dateTime
        )

        // `todo.add_item` does not return the new item's uid, so the entity handed back describes
        // what was asked for; reading the list again is what resolves the real uid.
        return .result(value: ReminderSchemaEntity(
            title: title,
            list: target,
            dueDate: dueDate,
            note: note.map(String.init)
        ))
    }
}
