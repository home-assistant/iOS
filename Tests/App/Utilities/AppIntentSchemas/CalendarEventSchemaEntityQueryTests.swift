import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The events Siri can pick from, read out of the cache: Home Assistant has no "fetch event by id"
/// endpoint, so the cache is the only source without a round trip.
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
}
