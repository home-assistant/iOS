import Foundation
import GRDB

/// A calendar event as it is cached in the database.
///
/// Distinct from `HACalendarEvent`, which decodes Home Assistant's wire format and whose custom
/// decoder can't also map flat database rows. This is the flat, persisted shape: it adds the
/// calendar the event belongs to, so cached events can be read back per calendar without a join.
public struct HACalendarEventRecord: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    public static let databaseTableName = GRDBDatabaseTable.HACalendarEvent.rawValue

    /// Deterministic, so re-fetching the same window overwrites rather than duplicates. Recurring
    /// events repeat their `uid`, so the occurrence's start is folded in.
    public let id: String
    public let serverId: String
    public let calendarEntityId: String
    /// Absent when the integration doesn't supply one; such events can be listed but not deleted.
    public let uid: String?
    public let recurrenceId: String?
    public let summary: String
    public let start: Date
    /// Exclusive for all-day events, matching what Home Assistant sends.
    public let end: Date
    public let isAllDay: Bool
    /// Named to avoid colliding with `CustomStringConvertible.description` on the record.
    public let eventDescription: String?
    public let location: String?
    public let rrule: String?

    public init(
        id: String,
        serverId: String,
        calendarEntityId: String,
        uid: String?,
        recurrenceId: String?,
        summary: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        eventDescription: String?,
        location: String?,
        rrule: String?
    ) {
        self.id = id
        self.serverId = serverId
        self.calendarEntityId = calendarEntityId
        self.uid = uid
        self.recurrenceId = recurrenceId
        self.summary = summary
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.eventDescription = eventDescription
        self.location = location
        self.rrule = rrule
    }

    /// Without a `uid` two events can share a start, so the summary and end are folded in to keep
    /// them apart; with a `uid` the start alone distinguishes the occurrences of a recurring event.
    /// An empty `uid` counts as missing, matching how the rest of the app treats it.
    public static func uniqueId(
        serverId: String,
        calendarEntityId: String,
        uid: String?,
        recurrenceId: String?,
        start: Date,
        end: Date,
        summary: String
    ) -> String {
        let uid = uid.flatMap { $0.isEmpty ? nil : $0 }
        var components = [
            serverId,
            calendarEntityId,
            uid ?? "",
            recurrenceId ?? "",
            String(start.timeIntervalSince1970),
        ]
        if uid == nil {
            components += [String(end.timeIntervalSince1970), summary]
        }
        return components.joined(separator: "|")
    }
}
