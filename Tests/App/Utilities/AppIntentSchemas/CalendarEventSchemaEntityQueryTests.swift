import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The events Siri can pick from: the exposed calendars are re-read from the server, then the cache
/// answers, because Home Assistant has no "fetch event by id" endpoint to resolve against.
@available(iOS 27.0, *)
final class CalendarEventSchemaEntityQueryTests: AppIntentSchemaTestCase {
    private let sut = CalendarEventSchemaEntityQuery()
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testSuggestedEntitiesPairsEachEventWithItsCalendar() async throws {
        try seedCalendar(entityId: "calendar.home", name: "Home")
        try seedEvent(id: "event-1", summary: "Dentist", start: start)

        let entities = try await sut.suggestedEntities()

        XCTAssertEqual(entities.map(\.title), ["Dentist"])
        XCTAssertEqual(entities.first?.calendar.title, "Home")
    }

    /// Newest first, so the events a person is most likely to mean come back before a year of old
    /// ones the rolling cache window still holds.
    func testEventsComeBackNewestFirst() async throws {
        try seedCalendar()
        try seedEvent(id: "older", summary: "Older", start: start)
        try seedEvent(id: "newer", summary: "Newer", start: start.addingTimeInterval(86400))

        let entities = try await sut.suggestedEntities()

        XCTAssertEqual(entities.map(\.title), ["Newer", "Older"])
    }

    /// The cache outlives the calendar list, so an event whose calendar is gone has nothing to be
    /// shown under and is dropped rather than offered with a blank one.
    func testAnEventWithoutItsCalendarIsDropped() async throws {
        try seedEvent(calendarEntityId: "calendar.deleted")

        let entities = try await sut.suggestedEntities()

        XCTAssertTrue(entities.isEmpty)
    }

    func testEventsOnAnOptedOutServerAreDropped() async throws {
        try seedCalendar()
        try seedEvent()
        try hideFromSiri(serverId)

        let entities = try await sut.suggestedEntities()

        XCTAssertTrue(entities.isEmpty)
    }

    func testEntitiesForIdentifiersResolvesOnlyWhatWasAskedFor() async throws {
        try seedCalendar()
        try seedEvent(id: "event-1", summary: "Dentist", start: start)
        try seedEvent(id: "event-2", summary: "Optician", start: start.addingTimeInterval(-86400))

        let entities = try await sut.entities(for: ["event-2", "gone"])

        XCTAssertEqual(entities.map(\.title), ["Optician"])
    }

    func testEntitiesMatchingSearchesTheTitleCaseInsensitively() async throws {
        try seedCalendar()
        try seedEvent(id: "event-1", summary: "Dentist", start: start)
        try seedEvent(id: "event-2", summary: "Optician", start: start.addingTimeInterval(-86400))

        let matched = try await sut.entities(matching: "DENT")
        let unmatched = try await sut.entities(matching: "swimming")

        XCTAssertEqual(matched.map(\.title), ["Dentist"])
        XCTAssertTrue(unmatched.isEmpty)
    }

    /// A database that cannot be read is reported as no events rather than as a failure, because
    /// the query is a picker source: an error there would take the whole intent down.
    func testAnUnreadableCacheComesBackEmpty() async throws {
        try seedCalendar()
        try seedEvent()
        let empty = try DatabaseQueue(path: ":memory:")
        Current.database = { empty }

        let entities = try await sut.suggestedEntities()

        XCTAssertTrue(entities.isEmpty)
    }

    // MARK: - Re-reading the server

    /// An event Siri itself just added is not in the cache until the calendar is read again, so the
    /// query cannot answer from the cache as it stands.
    func testSuggestedEntitiesReReadsTheExposedCalendarsBeforeAnswering() async throws {
        let calendar = try seedCalendar()
        calendarsModel.serverReturns([
            HACalendarEventRecord(
                id: "fresh",
                serverId: serverId,
                calendarEntityId: calendar.entityId,
                uid: "uid-fresh",
                recurrenceId: nil,
                summary: "Bruno test",
                start: Date(),
                end: Date().addingTimeInterval(3600),
                isAllDay: false,
                eventDescription: nil,
                location: nil,
                rrule: nil
            ),
        ], for: calendar)

        let entities = try await sut.suggestedEntities()

        XCTAssertEqual(calendarsModel.refreshedCalendars.map(\.id), [calendar.id])
        XCTAssertEqual(entities.map(\.title), ["Bruno test"])
        XCTAssertEqual(entities.first?.uid, "uid-fresh")
    }

    func testTheReReadCoversAMonthEitherSideOfNow() async throws {
        try seedCalendar()

        _ = try await sut.suggestedEntities()

        let request = try XCTUnwrap(calendarsModel.eventsRequests.first)
        let now = Date()
        XCTAssertTrue(request.covers(now.addingTimeInterval(-29 * 86400)))
        XCTAssertTrue(request.covers(now.addingTimeInterval(29 * 86400)))
    }

    func testResolvingAnIdentifierReReadsFirst() async throws {
        let calendar = try seedCalendar()
        let fresh = HACalendarEventRecord(
            id: "fresh",
            serverId: serverId,
            calendarEntityId: calendar.entityId,
            uid: "uid-fresh",
            recurrenceId: nil,
            summary: "Bruno test",
            start: Date(),
            end: Date().addingTimeInterval(3600),
            isAllDay: false,
            eventDescription: nil,
            location: nil,
            rrule: nil
        )
        calendarsModel.serverReturns([fresh], for: calendar)

        let entities = try await sut.entities(for: ["fresh"])

        XCTAssertEqual(entities.map(\.id), ["fresh"])
    }

    func testCalendarsOnAnOptedOutServerAreNotReRead() async throws {
        try seedCalendar()
        try hideFromSiri(serverId)

        _ = try await sut.suggestedEntities()

        XCTAssertTrue(calendarsModel.eventsRequests.isEmpty)
    }

    /// A calendar the server cannot be reached for keeps what the cache already held.
    func testACalendarTheServerCannotBeReachedForKeepsItsCachedEvents() async throws {
        try seedCalendar()
        try seedEvent(id: "old", summary: "Old", start: start, end: start.addingTimeInterval(3600))

        let entities = try await sut.suggestedEntities()

        XCTAssertEqual(entities.map(\.title), ["Old"])
    }

    /// An event the server no longer returns has been deleted there, so the re-read drops it.
    func testAnEventTheServerNoLongerReturnsLeavesTheCache() async throws {
        let calendar = try seedCalendar()
        let soon = Date().addingTimeInterval(3600)
        try seedEvent(id: "gone", summary: "Gone", start: soon, end: soon.addingTimeInterval(3600))
        calendarsModel.serverReturns([], for: calendar)

        let entities = try await sut.suggestedEntities()

        XCTAssertTrue(entities.isEmpty)
    }
}
