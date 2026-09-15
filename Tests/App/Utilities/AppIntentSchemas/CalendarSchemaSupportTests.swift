@testable import HomeAssistant
@testable import Shared
import XCTest

/// The lookups and validation every calendar schema intent goes through before it touches the
/// server.
@available(iOS 27.0, *)
final class CalendarSchemaSupportTests: AppIntentSchemaTestCase {
    // MARK: - Exposure

    func testExposedCalendarsReturnsEveryCalendarWhenNothingIsHidden() throws {
        try seedCalendar(entityId: "calendar.home", name: "Home", sortOrder: 0)
        try seedCalendar(entityId: "calendar.work", name: "Work", sortOrder: 1)

        XCTAssertEqual(CalendarSchemaSupport.exposedCalendars().map(\.name), ["Home", "Work"])
    }

    /// The setting is about what Siri may offer, so an opted-out server's calendars drop out here
    /// while the rest of the app keeps seeing them.
    func testExposedCalendarsLeavesOutAnOptedOutServer() throws {
        let other = servers.addFake()
        try seedCalendar(entityId: "calendar.home", name: "Home")
        try seedCalendar(entityId: "calendar.other", name: "Other", onServer: other.identifier.rawValue)
        try hideFromSiri(other.identifier.rawValue)

        XCTAssertEqual(CalendarSchemaSupport.exposedCalendars().map(\.name), ["Home"])
    }

    func testExposedCalendarResolvesOneById() throws {
        let calendar = try seedCalendar()

        XCTAssertEqual(CalendarSchemaSupport.exposedCalendar(id: calendar.id)?.entityId, "calendar.home")
        XCTAssertNil(CalendarSchemaSupport.exposedCalendar(id: "nope"))
    }

    /// An identifier saved before the opt-out has to stop resolving, rather than quietly still
    /// working for whoever kept a reference to it.
    func testExposedCalendarRefusesACalendarOnAnOptedOutServer() throws {
        let calendar = try seedCalendar()
        try hideFromSiri(serverId)

        XCTAssertNil(CalendarSchemaSupport.exposedCalendar(id: calendar.id))
    }

    // MARK: - Capability checks

    func testCalendarForEntityRequiresTheStoredCalendarToExist() throws {
        let entity = try CalendarSchemaEntity(calendar: seedCalendar())
        try database.write { db in
            _ = try HACalendar.deleteAll(db)
        }

        XCTAssertThrowsError(try CalendarSchemaSupport.calendar(for: entity, requiring: .createEvent)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.unknownCalendar
            )
        }
    }

    /// Home Assistant rejects an unsupported write server-side, so failing here gives the user a
    /// message naming the calendar instead of a bare service error.
    func testCalendarForEntityRefusesACalendarThatCannotDoTheThing() throws {
        // `createEvent` only; update and delete are not supported.
        let calendar = try seedCalendar(name: "Read Only", supportedFeatures: 1)
        let entity = CalendarSchemaEntity(calendar: calendar)

        XCTAssertEqual(try CalendarSchemaSupport.calendar(for: entity, requiring: .createEvent).id, calendar.id)
        for feature in [HACalendar.Feature.updateEvent, .deleteEvent] {
            XCTAssertThrowsError(try CalendarSchemaSupport.calendar(for: entity, requiring: feature)) { error in
                let message = (error as? ShortcutAppIntentError)?.errorDescription
                XCTAssertEqual(message?.contains("Read Only"), true, "expected \(feature) to name the calendar")
            }
        }
    }

    func testCalendarForEntityNamesTheCalendarForEveryUnsupportedFeature() throws {
        let entity = try CalendarSchemaEntity(calendar: seedCalendar(name: "Holidays", supportedFeatures: 0))
        let expected: [HACalendar.Feature: String] = [
            .createEvent: L10n.AppIntents.Calendar.Error.createUnsupported("Holidays"),
            .updateEvent: L10n.AppIntents.Calendar.Error.updateUnsupported("Holidays"),
            .deleteEvent: L10n.AppIntents.Calendar.Error.deleteUnsupported("Holidays"),
        ]

        for (feature, message) in expected {
            XCTAssertThrowsError(try CalendarSchemaSupport.calendar(for: entity, requiring: feature)) { error in
                XCTAssertEqual((error as? ShortcutAppIntentError)?.errorDescription, message)
            }
        }
    }

    // MARK: - Event identity

    /// Integrations that supply no uid produce events that can be listed but not changed, so the
    /// refusal has to say which of the two the caller was trying to do.
    func testUidRefusesAnEventWithoutOne() throws {
        let calendar = try CalendarSchemaEntity(calendar: seedCalendar())
        let record = try seedEvent(uid: nil, summary: "Bin day")
        let event = CalendarEventSchemaEntity(record: record, calendar: calendar)

        XCTAssertThrowsError(try CalendarSchemaSupport.uid(of: event, editing: true)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.eventNotEditable("Bin day")
            )
        }
        XCTAssertThrowsError(try CalendarSchemaSupport.uid(of: event, editing: false)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.eventNotDeletable("Bin day")
            )
        }
    }

    /// An empty string is the same as no uid at all: it addresses nothing.
    func testUidTreatsAnEmptyIdentifierAsMissing() throws {
        let calendar = try CalendarSchemaEntity(calendar: seedCalendar())
        let event = try CalendarEventSchemaEntity(record: seedEvent(uid: ""), calendar: calendar)

        XCTAssertThrowsError(try CalendarSchemaSupport.uid(of: event, editing: true))
    }

    func testUidReturnsTheStoredIdentifier() throws {
        let calendar = try CalendarSchemaEntity(calendar: seedCalendar())
        let event = try CalendarEventSchemaEntity(record: seedEvent(uid: "uid-42"), calendar: calendar)

        XCTAssertEqual(try CalendarSchemaSupport.uid(of: event, editing: true), "uid-42")
    }

    // MARK: - API resolution

    func testApiResolvesTheCalendarsOwnServer() throws {
        let calendar = try seedCalendar()

        XCTAssertNoThrow(try CalendarSchemaSupport.api(for: calendar))
    }

    func testApiRefusesACalendarWhoseServerIsGone() throws {
        let calendar = try seedCalendar(onServer: "missing-server")

        XCTAssertThrowsError(try CalendarSchemaSupport.api(for: calendar)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Error.noServer
            )
        }
    }

    // MARK: - Dates

    /// Matches how the frontend opens a new event: an hour for a timed one, the same day for an
    /// all-day one.
    func testResolvedEndFillsInAMissingEnd() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(
            CalendarSchemaSupport.resolvedEnd(nil, start: start, isAllDay: false),
            start.addingTimeInterval(60 * 60)
        )
        XCTAssertEqual(CalendarSchemaSupport.resolvedEnd(nil, start: start, isAllDay: true), start)
    }

    func testResolvedEndKeepsAnEndTheCallerGave() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1800)

        XCTAssertEqual(CalendarSchemaSupport.resolvedEnd(end, start: start, isAllDay: false), end)
        XCTAssertEqual(CalendarSchemaSupport.resolvedEnd(end, start: start, isAllDay: true), end)
    }

    /// The frontend's `_isValidStartEnd` rule: an all-day event may start and end on the same day
    /// because the stored end is exclusive, a timed one may not be instantaneous.
    func testValidateAllowsAZeroLengthAllDayEventButNotAZeroLengthTimedOne() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertNoThrow(try CalendarSchemaSupport.validate(start: start, end: start, isAllDay: true))
        XCTAssertThrowsError(try CalendarSchemaSupport.validate(start: start, end: start, isAllDay: false)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.zeroDuration
            )
        }
    }

    func testValidateRefusesAnEndBeforeItsStart() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(-60)

        XCTAssertThrowsError(try CalendarSchemaSupport.validate(start: start, end: end, isAllDay: true)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.invalidDuration
            )
        }
        XCTAssertThrowsError(try CalendarSchemaSupport.validate(start: start, end: end, isAllDay: false))
    }

    func testValidateAcceptsAForwardRange() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(60)

        XCTAssertNoThrow(try CalendarSchemaSupport.validate(start: start, end: end, isAllDay: false))
        XCTAssertNoThrow(try CalendarSchemaSupport.validate(start: start, end: end, isAllDay: true))
    }
}
