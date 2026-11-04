@testable import HomeAssistant
@testable import Shared
import XCTest

/// The to-do items Siri can pick from. They are not cached locally, so the query reads them from
/// the server a list at a time.
@available(iOS 27.0, *)
final class ReminderSchemaEntityQueryTests: AppIntentSchemaTestCase {
    private let sut = ReminderSchemaEntityQuery()

    func testSuggestedEntitiesReadsEveryListItHasAccessTo() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        let task = Task { try await sut.suggestedEntities() }

        let pending = try await request()
        XCTAssertEqual(pending.request.data["entity_id"] as? String, "todo.shopping")
        pending.completion(.success(todoItemsResponse(listId: "todo.shopping", items: [
            ["summary": "Milk", "uid": "uid-1", "status": "needs_action"],
        ])))

        let entities = try await task.value
        XCTAssertEqual(entities.map(\.title), ["Milk"])
        XCTAssertEqual(entities.first?.list.entityId, "todo.shopping")
    }

    /// One list failing must not take the others' items with it: the picker would rather be short
    /// a list than empty.
    func testAListThatFailsToReadIsSkippedRatherThanFailingTheWholeQuery() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")
        let task = Task { try await sut.suggestedEntities() }

        let first = try await request(at: 0)
        first.completion(.failure(.internal(debugDescription: "nope")))

        let second = try await request(at: 1)
        second.completion(.success(todoItemsResponse(listId: "todo.work", items: [
            ["summary": "Invoices", "uid": "uid-2", "status": "needs_action"],
        ])))

        let entities = try await task.value

        XCTAssertEqual(entities.map(\.title), ["Invoices"])
    }

    func testEntitiesForIdentifiersResolvesOnlyWhatWasAskedFor() async throws {
        let list = try seedTodoList(entityId: "todo.shopping")
        let wanted = "\(list.serverId)-todo.shopping-uid-2"
        let task = Task { try await sut.entities(for: [wanted]) }

        let pending = try await request()
        pending.completion(.success(todoItemsResponse(listId: "todo.shopping", items: [
            ["summary": "Milk", "uid": "uid-1", "status": "needs_action"],
            ["summary": "Bread", "uid": "uid-2", "status": "needs_action"],
        ])))

        let entities = try await task.value

        XCTAssertEqual(entities.map(\.title), ["Bread"])
    }

    func testEntitiesMatchingSearchesTheTitleCaseInsensitively() async throws {
        try seedTodoList(entityId: "todo.shopping")
        let task = Task { try await sut.entities(matching: "BREA") }

        let pending = try await request()
        pending.completion(.success(todoItemsResponse(listId: "todo.shopping", items: [
            ["summary": "Milk", "uid": "uid-1", "status": "needs_action"],
            ["summary": "Bread", "uid": "uid-2", "status": "needs_action"],
        ])))

        let entities = try await task.value

        XCTAssertEqual(entities.map(\.title), ["Bread"])
    }

    func testWithNoListsNothingIsRead() async throws {
        let entities = try await sut.suggestedEntities()

        XCTAssertTrue(entities.isEmpty)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// A list whose server is gone is skipped before anything is sent, rather than failing the
    /// query for the lists that are still reachable.
    func testAListOnAServerThatIsGoneIsSkipped() async throws {
        try seedTodoList(entityId: "todo.shopping", onServer: "missing-server")

        let entities = try await sut.suggestedEntities()

        XCTAssertTrue(entities.isEmpty)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }
}
