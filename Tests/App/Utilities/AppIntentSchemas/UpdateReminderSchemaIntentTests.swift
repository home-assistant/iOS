@testable import HomeAssistant
@testable import Shared
import XCTest

/// Editing an item on a Home Assistant to-do list.
@available(iOS 27.0, *)
final class UpdateReminderSchemaIntentTests: AppIntentSchemaTestCase {
    private func existingItem(note: String? = "Two pints") throws -> ReminderSchemaEntity {
        let list = ReminderListSchemaEntity(entity: try seedTodoList(entityId: "todo.shopping"))
        return ReminderSchemaEntity(
            item: TodoListItem(
                summary: "Milk",
                uid: "uid-1",
                status: "needs_action",
                description: note
            ),
            list: list
        )
    }

    private func intent(for item: ReminderSchemaEntity) -> UpdateReminderSchemaIntent {
        let intent = UpdateReminderSchemaIntent()
        intent.target = item
        return intent
    }

    func testTheItemIsAddressedByItsUidOnItsOwnList() async throws {
        let sut = intent(for: try existingItem())
        sut.title = "Oat milk"

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertTrue(route(of: pending).contains("services/todo/update_item"))
        XCTAssertEqual(pending.request.data["entity_id"] as? String, "todo.shopping")
        XCTAssertEqual(pending.request.data["item"] as? String, "uid-1")
        XCTAssertEqual(pending.request.data["rename"] as? String, "Oat milk")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// `todo.update_item` replaces the fields it is given, so anything the caller left out has to
    /// be sent back as it stands.
    func testFieldsTheCallerLeftOutAreRefilledFromTheItem() async throws {
        let sut = intent(for: try existingItem())

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["rename"] as? String, "Milk")
        XCTAssertEqual(pending.request.data["description"] as? String, "Two pints")
        XCTAssertEqual(pending.request.data["status"] as? String, "needs_action")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testCompletingAnItemSendsTheCompletedStatus() async throws {
        let sut = intent(for: try existingItem())
        sut.isCompleted = true

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["status"] as? String, "completed")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testANewNoteReplacesTheStoredOne() async throws {
        let sut = intent(for: try existingItem())
        sut.note = AttributedString("Oat, not soya")

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["description"] as? String, "Oat, not soya")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testANewDueDateIsSentInTheShapeItCarries() async throws {
        let sut = intent(for: try existingItem())
        sut.dueDate = DateComponents(year: 2023, month: 11, day: 14)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["due_date"] as? String, "2023-11-14")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// Moving an item between lists has no equivalent in the `todo` domain, so a named list is
    /// ignored rather than half-applied.
    func testANamedListDoesNotMoveTheItem() async throws {
        let sut = intent(for: try existingItem())
        sut.list = ReminderListSchemaEntity(entity: try seedTodoList(entityId: "todo.work", name: "Work"))

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["entity_id"] as? String, "todo.shopping")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testAnItemOnAServerThatIsGoneIsRefused() async throws {
        let list = ReminderListSchemaEntity(entity: try seedTodoList(onServer: "missing-server"))
        let sut = intent(for: ReminderSchemaEntity(
            item: TodoListItem(summary: "Milk", uid: "uid-1", status: "needs_action", description: nil),
            list: list
        ))

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
