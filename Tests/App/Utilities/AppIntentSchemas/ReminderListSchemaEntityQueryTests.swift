@testable import HomeAssistant
@testable import Shared
import XCTest

/// The to-do lists Siri can pick from.
@available(iOS 27.0, *)
final class ReminderListSchemaEntityQueryTests: AppIntentSchemaTestCase {
    private let sut = ReminderListSchemaEntityQuery()

    func testSuggestedEntitiesOffersEveryTodoList() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")

        let entities = try await sut.suggestedEntities()

        XCTAssertEqual(Set(entities.map(\.name)), ["Shopping", "Work"])
    }

    /// Only the `todo` domain: a light is not a list, and offering one would put it in the picker.
    func testEntitiesFromOtherDomainsAreNotOffered() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "light.kitchen", name: "Kitchen")

        let entities = try await sut.suggestedEntities()

        XCTAssertEqual(entities.map(\.entityId), ["todo.shopping"])
    }

    func testAnOptedOutServersListsAreNotOffered() async throws {
        try seedTodoList()
        try hideFromSiri(serverId)

        let entities = try await sut.suggestedEntities()

        XCTAssertTrue(entities.isEmpty)
    }

    func testEntitiesForIdentifiersResolvesOnlyWhatWasAskedFor() async throws {
        let shopping = try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")

        let entities = try await sut.entities(for: [shopping.id, "gone"])

        XCTAssertEqual(entities.map(\.name), ["Shopping"])
    }

    func testEntitiesMatchingSearchesTheNameCaseInsensitively() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")

        let matched = try await sut.entities(matching: "SHOP")
        let unmatched = try await sut.entities(matching: "garden")

        XCTAssertEqual(matched.map(\.name), ["Shopping"])
        XCTAssertTrue(unmatched.isEmpty)
    }

    func testTheListsFollowTheProvidersOrder() throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")

        XCTAssertEqual(sut.lists().map(\.entityId), ["todo.shopping", "todo.work"])
    }

    func testThereAreNoListsWithoutAnyLists() {
        XCTAssertTrue(sut.lists().isEmpty)
    }

    func testAListSwitchedOffInSettingsIsNotOffered() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")
        try hideEntityFromSiri("todo.work", domain: Domain.todo.rawValue)

        let entities = try await sut.suggestedEntities()

        XCTAssertEqual(entities.map(\.entityId), ["todo.shopping"])
    }

    func testTheDefaultListWinsOverTheFirstOne() throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")
        try makeSiriDefault("todo.work", domain: Domain.todo.rawValue)

        XCTAssertEqual(sut.defaultList()?.entityId, "todo.work")
    }

    func testTheDefaultResultIsTheDefaultList() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")
        try makeSiriDefault("todo.work", domain: Domain.todo.rawValue)

        let entity = await sut.defaultResult()

        XCTAssertEqual(entity?.entityId, "todo.work")
    }

    func testThereIsNoDefaultResultWithoutADefault() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")

        let entity = await sut.defaultResult()

        XCTAssertNil(entity)
    }

    func testADefaultOnAnOptedOutServerDoesNotCount() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try makeSiriDefault("todo.shopping", domain: Domain.todo.rawValue)
        try hideFromSiri(serverId)

        let entity = await sut.defaultResult()

        XCTAssertNil(entity)
    }
}
