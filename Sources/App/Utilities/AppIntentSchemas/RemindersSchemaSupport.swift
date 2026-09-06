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
        return api
    }

    /// The list a new reminder belongs on when the caller did not name one.
    static func defaultList() throws -> ReminderListSchemaEntity {
        guard let list = ReminderListSchemaEntityQuery().firstList() else {
            throw ShortcutAppIntentError(L10n.AppIntents.Reminders.Error.noList)
        }
        return list
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
