import AppIntents
import Foundation
import Shared

/// A Home Assistant todo item in the shape Apple Intelligence understands.
///
/// Home Assistant todo items carry a summary, a description, a due date and a status. Flags, tags,
/// URLs, location triggers and recurrence have no equivalent, so they stay empty or nil.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.reminder)
struct ReminderSchemaEntity {
    static let defaultQuery = ReminderSchemaEntityQuery()

    var id: String
    var title: String
    var list: ReminderListSchemaEntity
    var dueDate: DateComponents?
    var completionDate: Date?
    var creationDate: Date?
    var isCompleted: Bool
    var isFlagged: Bool?
    var recurrence: Calendar.RecurrenceRule?
    var locationTrigger: LocationTriggerSchemaEntity?
    var note: String?
    var tags: Set<String>
    var urls: [URL]

    /// The uid the todo services address, kept off the schema shape.
    var uid: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: "\(title)", image: .init(systemName: "checkmark.circle"))
    }

    init(item: TodoListItem, list: ReminderListSchemaEntity) {
        self.id = "\(list.serverId)-\(list.entityId)-\(item.uid)"
        self.uid = item.uid
        self.title = item.summary
        self.list = list
        // Home Assistant's due is a date alone or a date and time; keep only the fields it carries.
        self.dueDate = item.due.map { due in
            let fields: Set<Calendar.Component> = item.hasDueTime
                ? [.year, .month, .day, .hour, .minute]
                : [.year, .month, .day]
            return Calendar.current.dateComponents(fields, from: due)
        }
        self.isCompleted = item.status == "completed"
        self.note = item.description?.nilIfEmpty
        // Home Assistant exposes none of these.
        self.completionDate = nil
        self.creationDate = nil
        self.isFlagged = nil
        self.recurrence = nil
        self.locationTrigger = nil
        self.tags = []
        self.urls = []
    }

    /// An item described by what was just asked for. `todo.add_item` does not return a uid, so one
    /// is not known until the list is read again.
    init(title: String, list: ReminderListSchemaEntity, dueDate: DateComponents?, note: String?) {
        self.init(
            id: "\(list.serverId)-\(list.entityId)-\(title)",
            uid: "",
            title: title,
            list: list,
            dueDate: dueDate,
            isCompleted: false,
            note: note
        )
    }

    init(
        id: String,
        uid: String,
        title: String,
        list: ReminderListSchemaEntity,
        dueDate: DateComponents?,
        isCompleted: Bool,
        note: String?
    ) {
        self.id = id
        self.uid = uid
        self.title = title
        self.list = list
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.note = note
        self.completionDate = nil
        self.creationDate = nil
        self.isFlagged = nil
        self.recurrence = nil
        self.locationTrigger = nil
        self.tags = []
        self.urls = []
    }
}
