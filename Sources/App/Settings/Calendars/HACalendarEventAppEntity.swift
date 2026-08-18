import AppIntents
import Foundation
import Shared

/// A single occurrence of a Home Assistant calendar event, offered as the thing to act on in the
/// calendar App Intents.
///
/// The identifier carries everything needed to both display and delete the occurrence, so resolving
/// one never needs a round-trip: Home Assistant has no "fetch event by uid" endpoint, only a
/// windowed query, and a Shortcut that runs days after it was built would otherwise fail to resolve
/// an event that has scrolled out of the window it was picked from.
struct HACalendarEventAppEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.calendar.event.entity.name",
        defaultValue: "Calendar event"
    ))
    static let defaultQuery = HACalendarEventAppEntityQuery()

    let id: String
    let payload: Payload

    var displayRepresentation: DisplayRepresentation {
        .init(
            title: .init(stringLiteral: payload.summary),
            subtitle: .init(stringLiteral: "\(payload.calendarName) · \(formattedStart)"),
            image: .init(systemName: "calendar")
        )
    }

    private var formattedStart: String {
        let start = Date(timeIntervalSince1970: payload.start)
        return payload.isAllDay
            ? start.formatted(date: .abbreviated, time: .omitted)
            : start.formatted(date: .abbreviated, time: .shortened)
    }

    init?(payload: Payload) {
        guard let id = payload.encoded() else { return nil }
        self.id = id
        self.payload = payload
    }

    init?(id: String) {
        guard let payload = Payload(encoded: id) else { return nil }
        self.id = id
        self.payload = payload
    }

    /// `uid` is kept optional rather than filtered on: not every integration supplies one, and a
    /// listing intent should still return those events even though they can't be deleted.
    init?(event: HACalendarEvent, calendar: HACalendar) {
        self.init(payload: .init(
            serverId: calendar.serverId,
            calendarEntityId: calendar.entityId,
            calendarName: calendar.name,
            uid: event.uid,
            recurrenceId: event.recurrenceId,
            summary: event.summary,
            start: event.start.timeIntervalSince1970,
            isAllDay: event.isAllDay,
            isRecurring: event.recurrenceId != nil || event.rrule != nil
        ))
    }

    /// The self-contained description of an occurrence, round-tripped through the entity id.
    struct Payload: Codable, Hashable {
        let serverId: String
        let calendarEntityId: String
        let calendarName: String
        let uid: String?
        let recurrenceId: String?
        let summary: String
        /// Seconds since 1970, so the id stays stable regardless of locale or calendar.
        let start: TimeInterval
        let isAllDay: Bool
        /// Whether the occurrence belongs to a recurring series, which is what decides if the
        /// delete scope is meaningful.
        let isRecurring: Bool

        func encoded() -> String? {
            guard let data = try? JSONEncoder().encode(self) else { return nil }
            return data.base64EncodedString()
        }

        init?(encoded: String) {
            guard let data = Data(base64Encoded: encoded),
                  let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
            self = payload
        }

        init(
            serverId: String,
            calendarEntityId: String,
            calendarName: String,
            uid: String?,
            recurrenceId: String?,
            summary: String,
            start: TimeInterval,
            isAllDay: Bool,
            isRecurring: Bool
        ) {
            self.serverId = serverId
            self.calendarEntityId = calendarEntityId
            self.calendarName = calendarName
            self.uid = uid
            self.recurrenceId = recurrenceId
            self.summary = summary
            self.start = start
            self.isAllDay = isAllDay
            self.isRecurring = isRecurring
        }
    }
}
