@testable import HomeAssistant
@testable import Shared
import XCTest

/// The to-do item as Apple Intelligence sees it, both from the server's own shape and from what an
/// intent was just asked to create.
@available(iOS 27.0, *)
final class ReminderSchemaEntityTests: XCTestCase {
    private var list: ReminderListSchemaEntity {
        ReminderListSchemaEntity(entity: HAAppEntity(
            id: ServerEntity.uniqueId(serverId: "server", entityId: "todo.shopping"),
            entityId: "todo.shopping",
            serverId: "server",
            domain: "todo",
            name: "Shopping",
            icon: nil,
            rawDeviceClass: nil,
            entityCategory: nil,
            isHidden: nil
        ))
    }

    private func item(
        summary: String = "Milk",
        uid: String = "uid-1",
        status: String = "needs_action",
        description: String? = nil,
        dueRaw: String? = nil,
        due: Date? = nil
    ) -> TodoListItem {
        TodoListItem(
            summary: summary,
            uid: uid,
            status: status,
            description: description,
            dueRaw: dueRaw,
            due: due
        )
    }

    /// The id has to be unique across servers and lists, because every list's items land in one
    /// result; the uid alone is only unique within its list.
    func testTheIdentityCombinesTheServerTheListAndTheItem() {
        let sut = ReminderSchemaEntity(item: item(), list: list)

        XCTAssertEqual(sut.id, "server-todo.shopping-uid-1")
        XCTAssertEqual(sut.uid, "uid-1")
        XCTAssertEqual(sut.title, "Milk")
        XCTAssertEqual(sut.list.entityId, "todo.shopping")
    }

    func testCompletionFollowsTheServersStatus() {
        XCTAssertTrue(ReminderSchemaEntity(item: item(status: "completed"), list: list).isCompleted)
        XCTAssertFalse(ReminderSchemaEntity(item: item(status: "needs_action"), list: list).isCompleted)
    }

    /// A blank description is no note at all, not a note the user left empty.
    func testABlankDescriptionBecomesNoNote() {
        XCTAssertNil(ReminderSchemaEntity(item: item(description: ""), list: list).note)
        XCTAssertEqual(ReminderSchemaEntity(item: item(description: "2 pints"), list: list).note, "2 pints")
    }

    func testAnItemWithNoDueDateHasNone() {
        XCTAssertNil(ReminderSchemaEntity(item: item(), list: list).dueDate)
    }

    /// Home Assistant's due is a day alone or a day and a time; keeping only the fields it carries
    /// is what lets the update intent send it back in the same shape.
    func testADueDayCarriesNoTimeFields() {
        let due = Date(timeIntervalSince1970: 1_700_000_000)
        let sut = ReminderSchemaEntity(item: item(dueRaw: "2023-11-14", due: due), list: list)

        XCTAssertNotNil(sut.dueDate?.year)
        XCTAssertNotNil(sut.dueDate?.month)
        XCTAssertNotNil(sut.dueDate?.day)
        XCTAssertNil(sut.dueDate?.hour)
        XCTAssertNil(sut.dueDate?.minute)
    }

    func testADueDateTimeKeepsItsTimeFields() {
        let due = Date(timeIntervalSince1970: 1_700_000_000)
        let sut = ReminderSchemaEntity(item: item(dueRaw: "2023-11-14T22:13:20", due: due), list: list)

        XCTAssertNotNil(sut.dueDate?.hour)
        XCTAssertNotNil(sut.dueDate?.minute)
        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due),
            sut.dueDate
        )
    }

    /// Home Assistant exposes none of these, so they stay empty rather than being invented.
    func testTheFieldsHomeAssistantDoesNotHaveAreEmpty() {
        let sut = ReminderSchemaEntity(item: item(), list: list)

        XCTAssertNil(sut.completionDate)
        XCTAssertNil(sut.creationDate)
        XCTAssertNil(sut.isFlagged)
        XCTAssertNil(sut.recurrence)
        XCTAssertNil(sut.locationTrigger)
        XCTAssertTrue(sut.tags.isEmpty)
        XCTAssertTrue(sut.urls.isEmpty)
    }

    /// `todo.add_item` does not return a uid, so a just-created item has none until the list is
    /// read again — and it is never complete, because it was only just added.
    func testAJustCreatedItemHasNoUidAndIsNotComplete() {
        let sut = ReminderSchemaEntity(title: "Bread", list: list, dueDate: nil, note: "Sourdough")

        XCTAssertEqual(sut.id, "server-todo.shopping-Bread")
        XCTAssertTrue(sut.uid.isEmpty)
        XCTAssertEqual(sut.title, "Bread")
        XCTAssertEqual(sut.note, "Sourdough")
        XCTAssertFalse(sut.isCompleted)
    }

    func testAnItemDescribedByAnEditKeepsTheIdentityItWasEditedUnder() {
        let due = DateComponents(year: 2023, month: 11, day: 14)
        let sut = ReminderSchemaEntity(
            id: "server-todo.shopping-uid-1",
            uid: "uid-1",
            title: "Milk",
            list: list,
            dueDate: due,
            isCompleted: true,
            note: nil
        )

        XCTAssertEqual(sut.id, "server-todo.shopping-uid-1")
        XCTAssertEqual(sut.uid, "uid-1")
        XCTAssertEqual(sut.dueDate, due)
        XCTAssertTrue(sut.isCompleted)
        XCTAssertNil(sut.note)
    }

    func testTheItemIsShownUnderItsOwnTitle() {
        let sut = ReminderSchemaEntity(item: item(summary: "Oat milk"), list: list)

        XCTAssertEqual(String(localized: sut.displayRepresentation.title), "Oat milk")
    }
}
