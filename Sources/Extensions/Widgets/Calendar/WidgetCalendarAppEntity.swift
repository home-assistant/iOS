import AppIntents
import Foundation
import Shared

/// A Home Assistant calendar as offered in the calendar widget's configuration.
///
/// Distinct from the app target's `HACalendarAppEntity`, which the widget extension cannot see: the
/// calendar Shortcuts entities are compiled into the app only, the same way `TodoListAppEntity` is
/// the widget's own copy of a to-do list.
@available(iOS 17.0, *)
struct WidgetCalendarAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.calendar.entity.name",
        defaultValue: "Calendar"
    ))
    static let defaultQuery = WidgetCalendarAppEntityQuery()

    /// serverId-entityId, matching the stored `HACalendar`.
    let id: String
    let entityId: String
    let serverId: String
    let name: String

    /// The picker sections calendars by server, so the subtitle carries the entity id instead of
    /// repeating the server name — which is also what tells apart two calendars an integration
    /// named after itself rather than after the account.
    var displayRepresentation: DisplayRepresentation {
        .init(
            title: .init(stringLiteral: name),
            subtitle: .init(stringLiteral: entityId),
            image: .init(systemName: "calendar")
        )
    }

    init(id: String, entityId: String, serverId: String, name: String) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.name = name
    }

    init(calendar: HACalendar) {
        self.init(
            id: calendar.id,
            entityId: calendar.entityId,
            serverId: calendar.serverId,
            name: calendar.name
        )
    }
}
