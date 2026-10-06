@testable import HomeAssistant
@testable import Shared
import XCTest

/// The lookups and date formatting every reminders schema intent goes through.
@available(iOS 27.0, *)
final class RemindersSchemaSupportTests: AppIntentSchemaTestCase {
    // MARK: - API resolution

    func testApiResolvesTheListsOwnServer() throws {
        let list = try ReminderListSchemaEntity(entity: seedTodoList())

        XCTAssertNoThrow(try RemindersSchemaSupport.api(for: list))
    }

    func testApiRefusesAListWhoseServerIsGone() throws {
        let list = try ReminderListSchemaEntity(entity: seedTodoList(onServer: "missing-server"))

        XCTAssertThrowsError(try RemindersSchemaSupport.api(for: list)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Error.noServer
            )
        }
    }

    func testApiRefusesAListSwitchedOffForSiri() throws {
        let list = try ReminderListSchemaEntity(entity: seedTodoList())
        try hideEntityFromSiri(list.entityId, domain: Domain.todo.rawValue)

        XCTAssertThrowsError(try RemindersSchemaSupport.api(for: list)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Reminders.Error.listHidden
            )
        }
    }

    func testApiRefusesAListOnAnOptedOutServer() throws {
        let list = try ReminderListSchemaEntity(entity: seedTodoList())
        try hideFromSiri(serverId)

        XCTAssertThrowsError(try RemindersSchemaSupport.api(for: list)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Reminders.Error.listHidden
            )
        }
    }

    // MARK: - List resolution

    func testAConfiguredDefaultIsUsedWithoutAsking() throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")
        try makeSiriDefault("todo.work", domain: Domain.todo.rawValue)

        guard case let .only(list) = RemindersSchemaSupport.listResolution() else {
            return XCTFail("expected the default list to be picked without a choice")
        }
        XCTAssertEqual(list.entityId, "todo.work")
    }

    func testMoreThanOneListIsAChoiceInTheOrderOffered() throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")
        try seedTodoList(entityId: "todo.work", name: "Work")

        guard case let .choice(lists) = RemindersSchemaSupport.listResolution() else {
            return XCTFail("expected a choice between the lists")
        }
        XCTAssertEqual(lists.map(\.entityId), ["todo.shopping", "todo.work"])
    }

    func testASingleListIsUsedWithoutAsking() throws {
        try seedTodoList(entityId: "todo.shopping", name: "Shopping")

        guard case let .only(list) = RemindersSchemaSupport.listResolution() else {
            return XCTFail("expected the only list to be picked")
        }
        XCTAssertEqual(list.entityId, "todo.shopping")
    }

    func testThereIsNothingToResolveWhenThereAreNoLists() {
        guard case .noLists = RemindersSchemaSupport.listResolution() else {
            return XCTFail("expected no list")
        }
    }

    func testAnOptedOutServersListsAreNotOffered() throws {
        try seedTodoList()
        try hideFromSiri(serverId)

        guard case .noLists = RemindersSchemaSupport.listResolution() else {
            return XCTFail("expected a hidden server's lists to be left out")
        }
    }

    // MARK: - Due dates

    func testNoDueDateSendsNeitherField() {
        let due = RemindersSchemaSupport.due(nil)

        XCTAssertNil(due.date)
        XCTAssertNil(due.dateTime)
    }

    /// `todo.add_item` takes either a bare day or a datetime, never both, so a due date with no
    /// time component has to go out as a day.
    func testADayWithNoTimeIsSentAsADay() {
        let due = RemindersSchemaSupport.due(DateComponents(year: 2023, month: 11, day: 14))

        XCTAssertEqual(due.date, "2023-11-14")
        XCTAssertNil(due.dateTime)
    }

    func testADayWithATimeIsSentAsADateTime() throws {
        let components = DateComponents(year: 2023, month: 11, day: 14, hour: 9, minute: 30)
        let due = RemindersSchemaSupport.due(components)

        XCTAssertNil(due.date)
        XCTAssertNotNil(due.dateTime)
    }

    /// The datetime is what the server stores and hands back, so the instant has to survive the
    /// round trip whatever timezone it is written in.
    func testADueDateTimeSurvivesTheRoundTrip() throws {
        let components = DateComponents(year: 2023, month: 11, day: 14, hour: 9, minute: 30)
        let sent = try XCTUnwrap(RemindersSchemaSupport.due(components).dateTime)

        XCTAssertEqual(TodoListItem.parseDueDateTime(sent), Calendar.current.date(from: components))
    }

    /// Midnight is a time the user picked, not the absence of one: sending it as a bare day would
    /// drop it.
    func testMidnightCountsAsATime() {
        let due = RemindersSchemaSupport.due(DateComponents(year: 2023, month: 11, day: 14, hour: 0, minute: 0))

        XCTAssertNil(due.date)
        XCTAssertNotNil(due.dateTime)
    }
}
