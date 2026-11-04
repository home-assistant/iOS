import AppIntents
import Foundation
import Shared

/// Lists the items on a Home Assistant todo list.
///
/// The reminders schema has no read action — Apple only defines create, update and delete — so this
/// is a plain intent. It returns the same entity the update and delete intents take, so a Shortcut
/// can read a list and act on what it finds without an intermediate step.
@available(iOS 27.0, *)
struct GetRemindersAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.reminders.get_items.title",
        defaultValue: "Get to-do items"
    )

    static var description = IntentDescription(.init(
        "app_intents.reminders.get_items.description",
        defaultValue: "Get the items on a Home Assistant to-do list"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$list
            \.$includeCompleted
        }
    }

    @Parameter(title: .init("app_intents.reminders.list.name", defaultValue: "List"))
    var list: ReminderListSchemaEntity

    @Parameter(
        title: .init("app_intents.reminders.get_items.include_completed.title", defaultValue: "Include completed"),
        default: false
    )
    var includeCompleted: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<[ReminderSchemaEntity]> {
        await Current.connectivity.refreshNetworkInformation()

        let api = try RemindersSchemaSupport.api(for: list)
        let items = try await api.todoListItems(listId: list.entityId)
            .map { ReminderSchemaEntity(item: $0, list: list) }

        return .result(value: includeCompleted ? items : items.filter { !$0.isCompleted })
    }
}
