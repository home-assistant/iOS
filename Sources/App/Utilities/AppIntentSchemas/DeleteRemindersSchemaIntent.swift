import AppIntents
import Foundation
import Shared

/// Removes items from Home Assistant todo lists.
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.deleteReminders)
struct DeleteRemindersSchemaIntent {
    var entities: [ReminderSchemaEntity]

    func perform() async throws -> some IntentResult {
        // Items can come from different lists, and each list lives on its own server, so the API is
        // resolved per item rather than once up front.
        for item in entities {
            let api = try RemindersSchemaSupport.api(for: item.list)
            try await api.removeTodoItem(listId: item.list.entityId, itemId: item.uid)
        }
        return .result()
    }
}
