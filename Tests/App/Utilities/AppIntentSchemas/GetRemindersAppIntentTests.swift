@testable import HomeAssistant
@testable import Shared
import XCTest

/// Reading a Home Assistant to-do list.
///
/// The reminders schema has no read action, so this is a plain intent. `perform()` hands back an
/// opaque result, so what it asked the server for is what is checked here; the items it builds from
/// the answer are covered by `ReminderSchemaEntityTests`.
@available(iOS 27.0, *)
final class GetRemindersAppIntentTests: AppIntentSchemaTestCase {
    private func intent(list: ReminderListSchemaEntity, includeCompleted: Bool = false) -> GetRemindersAppIntent {
        let intent = GetRemindersAppIntent()
        intent.list = list
        intent.includeCompleted = includeCompleted
        return intent
    }

    func testTheNamedListIsRead() async throws {
        let list = ReminderListSchemaEntity(entity: try seedTodoList(entityId: "todo.shopping"))
        let sut = intent(list: list)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertTrue(route(of: pending).contains("services/todo/get_items"))
        XCTAssertEqual(pending.request.data["entity_id"] as? String, "todo.shopping")

        pending.completion(.success(todoItemsResponse(listId: "todo.shopping", items: [
            ["summary": "Milk", "uid": "uid-1", "status": "needs_action"],
            ["summary": "Bread", "uid": "uid-2", "status": "completed"],
        ])))
        _ = try await task.value
    }

    func testTheAnswerIsReadWhetherOrNotCompletedItemsAreWanted() async throws {
        let list = ReminderListSchemaEntity(entity: try seedTodoList(entityId: "todo.shopping"))
        let sut = intent(list: list, includeCompleted: true)

        let task = Task { try await sut.perform() }
        let pending = try await request()
        pending.completion(.success(todoItemsResponse(listId: "todo.shopping", items: [
            ["summary": "Bread", "uid": "uid-2", "status": "completed"],
        ])))

        _ = try await task.value
    }

    /// A list whose entity id the server does not report back has no items, rather than failing.
    func testAListTheServerDoesNotAnswerForComesBackEmpty() async throws {
        let list = ReminderListSchemaEntity(entity: try seedTodoList(entityId: "todo.shopping"))
        let sut = intent(list: list)

        let task = Task { try await sut.perform() }
        let pending = try await request()
        pending.completion(.success(todoItemsResponse(listId: "todo.other", items: [])))

        _ = try await task.value
    }

    func testAListOnAServerThatIsGoneIsRefused() async throws {
        let list = ReminderListSchemaEntity(entity: try seedTodoList(onServer: "missing-server"))
        let sut = intent(list: list)

        do {
            _ = try await sut.perform()
            XCTFail("expected a list on a missing server to be refused")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Error.noServer
            )
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }
}
