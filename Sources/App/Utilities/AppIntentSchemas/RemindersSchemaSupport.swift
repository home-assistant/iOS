import AppIntents
import Foundation
import Shared

/// Lookups and date formatting shared by the reminders schema intents.
@available(iOS 27.0, *)
enum RemindersSchemaSupport {
    static func api(for list: ReminderListSchemaEntity) throws -> HomeAssistantAPI {
        guard let server = Current.servers.server(for: .init(rawValue: list.serverId)),
              let api = Current.api(for: server) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }
        guard SiriServerExposure.isExposed(serverId: list.serverId),
              SiriEntityExposure.isExposed(serverId: list.serverId, entityId: list.entityId) else {
            Current.Log.error("List \(list.id) is not exposed to Siri")
            throw ShortcutAppIntentError(L10n.AppIntents.Reminders.Error.listHidden)
        }
        return api
    }

    static func listResolution() -> ReminderListResolution {
        let query = ReminderListSchemaEntityQuery()
        if let list = query.defaultList() {
            return .only(list)
        }
        return ReminderListResolution(lists: query.lists())
    }

    static var disambiguateList: (
        IntentParameter<ReminderListSchemaEntity?>,
        [ReminderListSchemaEntity]
    ) async throws -> ReminderListSchemaEntity = { parameter, lists in
        try await parameter.requestDisambiguation(
            among: lists,
            dialog: IntentDialog(.init(
                "app_intents.reminders.create.which_list",
                defaultValue: "Which list?"
            ))
        )
    }

    /// `todo.add_item` and `todo.update_item` take either a bare day or a datetime, never both, so
    /// a due date with no time component is sent as a day.
    static func due(_ components: DateComponents?) -> (date: String?, dateTime: String?) {
        guard let components, let date = Calendar.current.date(from: components) else {
            return (nil, nil)
        }
        let hasTime = components.hour != nil || components.minute != nil
        return hasTime
            ? (nil, dateTimeFormatter.string(from: date))
            : (dayFormatter.string(from: date), nil)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let dateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
