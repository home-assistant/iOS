import AppIntents
import Foundation

/// Home Assistant has one kind of todo list, so this is always `.standard`. The schema requires
/// that case by name.
@available(iOS 27.0, *)
@AppEnum(schema: .reminders.listType)
enum ReminderListTypeSchemaEnum: String {
    case standard

    static let caseDisplayRepresentations: [ReminderListTypeSchemaEnum: DisplayRepresentation] = [
        .standard: .init(title: .init("app_intents.reminders.list_type.standard", defaultValue: "List")),
    ]
}
