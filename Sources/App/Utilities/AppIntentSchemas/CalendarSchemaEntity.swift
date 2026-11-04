import AppIntents
import CoreSpotlight
import Foundation
import Shared

/// A Home Assistant calendar in the shape Apple Intelligence understands.
///
/// Parallel to `HACalendarAppEntity` rather than replacing it: the schema domain is iOS 27, and
/// annotating the shipped entity would drag its query, the calendar intents and the Spotlight
/// extension to iOS 27 with it, putting calendars out of reach for everyone below that.
@available(iOS 27.0, *)
@AppEntity(schema: .calendar.calendar)
struct CalendarSchemaEntity: IndexedEntity {
    static let defaultQuery = CalendarSchemaEntityQuery()

    var id: String
    var title: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: "\(title)", image: .init(systemName: "calendar"))
    }

    init(calendar: HACalendar) {
        self.id = calendar.id
        self.title = calendar.name
    }
}
