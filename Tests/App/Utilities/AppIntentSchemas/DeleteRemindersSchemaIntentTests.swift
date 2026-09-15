@testable import HomeAssistant
@testable import Shared
import XCTest

/// Removing items from Home Assistant to-do lists.
@available(iOS 27.0, *)
final class DeleteRemindersSchemaIntentTests: AppIntentSchemaTestCase {
    private func item(uid: String, list: ReminderListSchemaEntity) -> ReminderSchemaEntity {
        ReminderSchemaEntity(
            item: TodoListItem(summary: "Milk", uid: uid, status: "needs_action", description: nil),
            list: list
        )
    }

    func testTheItemIsRemovedFromItsOwnList() async throws {
        let list = ReminderListSchemaEntity(entity: try seedTodoList(entityId: "todo.shopping"))
        let sut = DeleteRemindersSchemaIntent()
        sut.entities = [item(uid: "uid-1", list: list)]

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertTrue(route(of: pending).contains("services/todo/remove_item"))
        XCTAssertEqual(pending.request.data["entity_id"] as? String, "todo.shopping")
        XCTAssertEqual(pending.request.data["item"] as? String, "uid-1")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// Items can come from different lists, and each list lives on its own server, so each one is
    /// removed through its own list rather than all through the first.
    func testEachItemIsRemovedThroughItsOwnList() async throws {
        let shopping = ReminderListSchemaEntity(entity: try seedTodoList(entityId: "todo.shopping"))
        let work = ReminderListSchemaEntity(entity: try seedTodoList(entityId: "todo.work", name: "Work"))
        let sut = DeleteRemindersSchemaIntent()
        sut.entities = [item(uid: "uid-1", list: shopping), item(uid: "uid-2", list: work)]

        let task = Task { try await sut.perform() }
        let first = try await request(at: 0)
        XCTAssertEqual(first.request.data["entity_id"] as? String, "todo.shopping")
        first.completion(.success(.dictionary([:])))

        let second = try await request(at: 1)
        XCTAssertEqual(second.request.data["entity_id"] as? String, "todo.work")
        XCTAssertEqual(second.request.data["item"] as? String, "uid-2")
        second.completion(.success(.dictionary([:])))

        _ = try await task.value
    }

    func testDeletingNothingSendsNothing() async throws {
        let sut = DeleteRemindersSchemaIntent()
        sut.entities = []

        _ = try await sut.perform()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testAnItemOnAServerThatIsGoneIsRefused() async throws {
        let list = ReminderListSchemaEntity(entity: try seedTodoList(onServer: "missing-server"))
        let sut = DeleteRemindersSchemaIntent()
        sut.entities = [item(uid: "uid-1", list: list)]

        do {
            _ = try await sut.perform()
            XCTFail("expected an item on a missing server to be refused")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Error.noServer
            )
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }
}
