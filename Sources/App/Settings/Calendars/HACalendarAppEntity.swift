import AppIntents
import CoreSpotlight
import Foundation
import Shared

/// A Home Assistant calendar exposed to the system, so Siri, Apple Intelligence and Spotlight can
/// refer to it by name.
///
/// This is deliberately a plain `AppEntity` rather than an App Schema entity: the calendar schema
/// domain (`.calendar.calendar`) only exists in the iOS 27 SDK, while the project still builds
/// against Xcode 26.4. The shape below is the one the schema expects, so adopting
/// `@AppEntity(schema: .calendar.calendar)` later is an annotation change rather than a rewrite.
struct HACalendarAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.calendar.entity.name",
        defaultValue: "Calendar"
    ))
    static let defaultQuery = HACalendarAppEntityQuery()

    let id: String
    let name: String
    let entityId: String
    let serverId: String
    let serverName: String?

    var displayRepresentation: DisplayRepresentation {
        .init(
            title: .init(stringLiteral: name),
            subtitle: serverName.map { .init(stringLiteral: $0) },
            image: .init(systemName: "calendar")
        )
    }

    init(id: String, name: String, entityId: String, serverId: String, serverName: String?) {
        self.id = id
        self.name = name
        self.entityId = entityId
        self.serverId = serverId
        self.serverName = serverName
    }

    init(calendar: HACalendar) {
        self.init(
            id: calendar.id,
            name: calendar.name,
            entityId: calendar.entityId,
            serverId: calendar.serverId,
            serverName: Current.servers.server(forServerIdentifier: calendar.serverId)?.info.name
        )
    }
}

/// Semantic indexing is what lets Siri resolve "my family calendar" to this entity without an exact
/// string match. It arrived in iOS 18, so the conformance is gated while the app still supports 17.
@available(iOS 18, *)
extension HACalendarAppEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let attributeSet = defaultAttributeSet
        attributeSet.contentDescription = entityId
        attributeSet.keywords = [name, entityId, serverName].compactMap { $0 }
        return attributeSet
    }
}
