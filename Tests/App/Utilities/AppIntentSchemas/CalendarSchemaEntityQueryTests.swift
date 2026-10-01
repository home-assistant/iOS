@testable import HomeAssistant
@testable import Shared
import XCTest

/// The calendars Siri can pick from.
@available(iOS 27.0, *)
final class CalendarSchemaEntityQueryTests: AppIntentSchemaTestCase {
    private let sut = CalendarSchemaEntityQuery()

    func testSuggestedEntitiesOffersEveryExposedCalendar() async throws {
        try seedCalendar(entityId: "calendar.home", name: "Home", sortOrder: 0)
        try seedCalendar(entityId: "calendar.work", name: "Work", sortOrder: 1)

        let entities = try await sut.suggestedEntities()

        XCTAssertEqual(entities.map(\.title), ["Home", "Work"])
    }

    func testSuggestedEntitiesLeavesOutAnOptedOutServer() async throws {
        try seedCalendar(name: "Home")
        try hideFromSiri(serverId)

        let entities = try await sut.suggestedEntities()

        XCTAssertTrue(entities.isEmpty)
    }

    func testEntitiesForIdentifiersResolvesOnlyWhatWasAskedFor() async throws {
        let home = try seedCalendar(entityId: "calendar.home", name: "Home", sortOrder: 0)
        try seedCalendar(entityId: "calendar.work", name: "Work", sortOrder: 1)

        let entities = try await sut.entities(for: [home.id, "not-a-calendar"])

        XCTAssertEqual(entities.map(\.title), ["Home"])
    }

    /// The name is what a person says, and the entity id is what a Shortcut is likely to carry, so
    /// both have to match — neither case-sensitively.
    func testEntitiesMatchingSearchesNameAndEntityId() async throws {
        try seedCalendar(entityId: "calendar.bin_collection", name: "Rubbish", sortOrder: 0)
        try seedCalendar(entityId: "calendar.work", name: "Work", sortOrder: 1)

        let byName = try await sut.entities(matching: "rubbish")
        let byEntityId = try await sut.entities(matching: "BIN_COLLECTION")
        let noMatch = try await sut.entities(matching: "holidays")

        XCTAssertEqual(byName.map(\.title), ["Rubbish"])
        XCTAssertEqual(byEntityId.map(\.title), ["Rubbish"])
        XCTAssertTrue(noMatch.isEmpty)
    }

    func testEntitiesMatchingStillHonoursTheOptOut() async throws {
        try seedCalendar(name: "Home")
        try hideFromSiri(serverId)

        let entities = try await sut.entities(matching: "home")

        XCTAssertTrue(entities.isEmpty)
    }

    func testACalendarSwitchedOffInSettingsIsNotOffered() async throws {
        try seedCalendar(entityId: "calendar.home", name: "Home", sortOrder: 0)
        let work = try seedCalendar(entityId: "calendar.work", name: "Work", sortOrder: 1)
        try hideEntityFromSiri("calendar.work", domain: Domain.calendar.rawValue)

        let suggested = try await sut.suggestedEntities()
        let byId = try await sut.entities(for: [work.id])
        let matching = try await sut.entities(matching: "work")

        XCTAssertEqual(suggested.map(\.title), ["Home"])
        XCTAssertTrue(byId.isEmpty)
        XCTAssertTrue(matching.isEmpty)
    }

    func testTheDefaultResultIsTheDefaultCalendar() async throws {
        try seedCalendar(entityId: "calendar.home", name: "Home", sortOrder: 0)
        try seedCalendar(entityId: "calendar.work", name: "Work", sortOrder: 1)
        try makeSiriDefault("calendar.work", domain: Domain.calendar.rawValue)

        let entity = await sut.defaultResult()

        XCTAssertEqual(entity?.title, "Work")
    }

    func testThereIsNoDefaultResultWithoutADefault() async throws {
        try seedCalendar(name: "Home")

        let entity = await sut.defaultResult()

        XCTAssertNil(entity)
    }
}
