import AppIntents
import Foundation

/// Home Assistant todo lists have no sections, so this only ever appears as nil on a reminder. It
/// exists because the schema requires the parameter to have this shape.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.section)
struct ReminderSectionSchemaEntity: TransientAppEntity {
    var name: String
    var list: ReminderListSchemaEntity

    var displayRepresentation: DisplayRepresentation {
        .init(title: "\(name)")
    }

    init() {
        self.name = ""
        self.list = ReminderListSchemaEntity()
    }
}
