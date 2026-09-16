@testable import HomeAssistant
@testable import Shared
import XCTest

/// Adding an item to a Home Assistant to-do list.
@available(iOS 27.0, *)
final class CreateReminderSchemaIntentTests: AppIntentSchemaTestCase {
    private func intent(list: ReminderListSchemaEntity?) -> CreateReminderSchemaIntent {
        let intent = CreateReminderSchemaIntent()
        intent.title = "Milk"
        intent.list = list
        intent.images = []
        intent.tags = []
        intent.urls = []
        return intent
    }

    func testTheItemIsAddedToTheNamedList() async throws {
        let list = try ReminderListSchemaEntity(entity: seedTodoList(entityId: "todo.shopping"))
        let sut = intent(list: list)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertTrue(route(of: pending).contains("services/todo/add_item"))
        XCTAssertEqual(pending.request.data["entity_id"] as? String, "todo.shopping")
        XCTAssertEqual(pending.request.data["item"] as? String, "Milk")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testWithoutAListTheOnlyOneIsUsedWithoutAsking() async throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        let sut = intent(list: nil)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["entity_id"] as? String, "todo.shopping")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testTheNoteIsSentAsTheDescription() async throws {
        let list = try ReminderListSchemaEntity(entity: seedTodoList())
        let sut = intent(list: list)
        sut.note = AttributedString("Two pints")

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["description"] as? String, "Two pints")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// `todo.add_item` takes a bare day or a datetime, never both.
    func testADueDayWithNoTimeIsSentAsADay() async throws {
        let sut = try intent(list: ReminderListSchemaEntity(entity: seedTodoList()))
        sut.dueDate = DateComponents(year: 2023, month: 11, day: 14)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["due_date"] as? String, "2023-11-14")
        XCTAssertNil(pending.request.data["due_datetime"])

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testADueDayWithATimeIsSentAsADateTime() async throws {
        let sut = try intent(list: ReminderListSchemaEntity(entity: seedTodoList()))
        sut.dueDate = DateComponents(year: 2023, month: 11, day: 14, hour: 9, minute: 30)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertNil(pending.request.data["due_date"])
        XCTAssertNotNil(pending.request.data["due_datetime"])

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// The `todo` domain has nowhere to put these, and folding them into the note would put text on
    /// the list the user never dictated.
    func testTheFieldsHomeAssistantCannotStoreAreNotSent() async throws {
        let list = try ReminderListSchemaEntity(entity: seedTodoList())
        let sut = intent(list: list)
        sut.isFlagged = true
        sut.tags = ["urgent"]
        sut.urls = [URL(string: "https://example.com")!]
        sut.locationTrigger = LocationTriggerSchemaEntity()
        sut.section = ReminderSectionSchemaEntity()
        sut.recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .daily)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data.count, 2)
        XCTAssertNil(pending.request.data["description"])

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testWithNoListsAtAllThereIsNothingToAddTo() async throws {
        let sut = intent(list: nil)

        do {
            _ = try await sut.perform()
            XCTFail("expected creating with no lists to be refused")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Reminders.Error.noList
            )
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }
}
