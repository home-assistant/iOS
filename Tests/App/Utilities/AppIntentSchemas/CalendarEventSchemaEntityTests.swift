@testable import HomeAssistant
@testable import Shared
import XCTest

/// The event as Apple Intelligence sees it, both from a cached record and from what an intent was
/// just asked to create.
@available(iOS 27.0, *)
final class CalendarEventSchemaEntityTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private var calendar: CalendarSchemaEntity {
        CalendarSchemaEntity(calendar: HACalendar(
            id: "server-calendar.home",
            serverId: "server",
            entityId: "calendar.home",
            name: "Home",
            backgroundColor: "#4269d0",
            supportedFeatures: 7,
            sortOrder: 0
        ))
    }

    private func record(
        uid: String? = "uid-1",
        recurrenceId: String? = nil,
        isAllDay: Bool = false,
        eventDescription: String? = nil,
        location: String? = nil
    ) -> HACalendarEventRecord {
        HACalendarEventRecord(
            id: "event-1",
            serverId: "server",
            calendarEntityId: "calendar.home",
            uid: uid,
            recurrenceId: recurrenceId,
            summary: "Dentist",
            start: start,
            end: start.addingTimeInterval(3600),
            isAllDay: isAllDay,
            eventDescription: eventDescription,
            location: location,
            rrule: nil
        )
    }

    func testACachedRecordKeepsItsIdentityAndTimes() {
        let sut = CalendarEventSchemaEntity(record: record(recurrenceId: "rec-1"), calendar: calendar)

        XCTAssertEqual(sut.id, "event-1")
        XCTAssertEqual(sut.uid, "uid-1")
        XCTAssertEqual(sut.recurrenceId, "rec-1")
        XCTAssertEqual(sut.title, "Dentist")
        XCTAssertEqual(sut.startDate, start)
        XCTAssertEqual(sut.endDate, start.addingTimeInterval(3600))
        XCTAssertFalse(sut.isAllDay)
        XCTAssertEqual(sut.calendar.id, "server-calendar.home")
    }

    func testAllDayIsCarriedAcross() {
        XCTAssertTrue(CalendarEventSchemaEntity(record: record(isAllDay: true), calendar: calendar).isAllDay)
    }

    /// Home Assistant omits a uid for integrations that don't supply one; such an event is listed
    /// but cannot be edited, so the entity has to say so rather than invent one.
    func testAnEventWithoutAUidKeepsNone() {
        XCTAssertNil(CalendarEventSchemaEntity(record: record(uid: nil), calendar: calendar).uid)
    }

    /// A blank description or location is nothing, not an empty value the user typed.
    func testBlankTextFieldsBecomeNothing() {
        let sut = CalendarEventSchemaEntity(
            record: record(eventDescription: "", location: ""),
            calendar: calendar
        )

        XCTAssertNil(sut.note)
        XCTAssertNil(sut.location)
    }

    func testTextFieldsAreCarriedAcross() {
        let sut = CalendarEventSchemaEntity(
            record: record(eventDescription: "Bring the form", location: "High Street"),
            calendar: calendar
        )

        XCTAssertEqual(sut.note, "Bring the form")
        XCTAssertEqual(sut.location?.plainText, "High Street")
    }

    /// Home Assistant has no concept of any of these, and an empty list is the truthful answer for
    /// an event that has none — not a placeholder to be filled in later.
    func testTheFieldsHomeAssistantDoesNotHaveAreEmpty() {
        let sut = CalendarEventSchemaEntity(record: record(), calendar: calendar)

        XCTAssertNil(sut.virtualLocation)
        XCTAssertTrue(sut.attendees.isEmpty)
        XCTAssertTrue(sut.organizers.isEmpty)
        XCTAssertNil(sut.recurrence)
        XCTAssertTrue(sut.alarms.isEmpty)
        XCTAssertNil(sut.status)
        XCTAssertNil(sut.travelTime)
    }

    /// `calendar/event/create` and `/update` return nothing, so this shape describes what was asked
    /// for; the uid stays unknown until the calendar is read again.
    func testAnEventDescribedByWhatWasAskedForCarriesNoIdentifiers() {
        let sut = CalendarEventSchemaEntity(
            id: "new-1",
            title: "Lunch",
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            isAllDay: false,
            calendar: calendar,
            location: .text("Canteen"),
            note: "With Sam"
        )

        XCTAssertEqual(sut.id, "new-1")
        XCTAssertNil(sut.uid)
        XCTAssertNil(sut.recurrenceId)
        XCTAssertEqual(sut.title, "Lunch")
        XCTAssertEqual(sut.location?.plainText, "Canteen")
        XCTAssertEqual(sut.note, "With Sam")
        XCTAssertTrue(sut.attendees.isEmpty)
    }

    func testTheEventIsShownUnderItsOwnTitle() {
        let sut = CalendarEventSchemaEntity(record: record(), calendar: calendar)

        XCTAssertEqual(String(localized: sut.displayRepresentation.title), "Dentist")
    }
}
