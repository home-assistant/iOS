import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

struct RemindersSyncItemSnapshotTests {
    // MARK: - Building from Home Assistant items

    @Test func testTodoItemInitTrimsTitleAndMapsStatus() {
        let snapshot = RemindersSyncItemSnapshot(todoItem: TodoListItem(
            summary: "  Buy milk \n",
            uid: "todo-1",
            status: "completed",
            description: nil
        ))
        #expect(snapshot.title == "Buy milk")
        #expect(snapshot.isCompleted)
        #expect(snapshot.notes == nil)
        #expect(snapshot.due == nil)
    }

    @Test func testTodoItemInitTreatsBlankDescriptionAsNoNotes() {
        let snapshot = RemindersSyncItemSnapshot(todoItem: TodoListItem(
            summary: "Buy milk",
            uid: "todo-1",
            status: "needs_action",
            description: "   \n"
        ))
        #expect(!snapshot.isCompleted)
        #expect(snapshot.notes == nil)
    }

    @Test func testTodoItemInitKeepsAllDayDueDateVerbatim() {
        let snapshot = RemindersSyncItemSnapshot(todoItem: TodoListItem(
            summary: "Buy milk",
            uid: "todo-1",
            status: "needs_action",
            description: nil,
            dueRaw: "2026-07-17"
        ))
        #expect(snapshot.due == "2026-07-17")
        #expect(!snapshot.hasDueTime)
        #expect(snapshot.dueDateArgument == "2026-07-17")
        #expect(snapshot.dueDateTimeArgument == nil)
    }

    @Test func testTodoItemInitCanonicalizesTimedDueDate() {
        let date = Date(timeIntervalSince1970: 1_784_000_000)
        let snapshot = RemindersSyncItemSnapshot(todoItem: TodoListItem(
            summary: "Buy milk",
            uid: "todo-1",
            status: "needs_action",
            description: nil,
            dueRaw: "2026-07-17T10:00:00+00:00",
            due: date
        ))
        #expect(snapshot.due == RemindersSyncItemSnapshot.canonicalDueString(from: date))
        #expect(snapshot.hasDueTime)
        #expect(snapshot.dueDateArgument == nil)
        #expect(snapshot.dueDateTimeArgument == snapshot.due)
    }

    @Test func testTodoItemInitCanonicalizesTimedDueDateFromRawStringFallback() {
        // TodoListItem fails to parse some server datetime formats, leaving `due` nil; the
        // snapshot must still canonicalize from the raw string so comparisons stay stable.
        let snapshot = RemindersSyncItemSnapshot(todoItem: TodoListItem(
            summary: "Buy milk",
            uid: "todo-1",
            status: "needs_action",
            description: nil,
            dueRaw: "2026-07-14T03:33:20+00:00",
            due: nil
        ))
        let expected = RemindersSyncItemSnapshot
            .canonicalDueString(from: Date(timeIntervalSince1970: 1_784_000_000))
        #expect(snapshot.due == expected)
    }

    // MARK: - Due date round-trips

    @Test func testAllDayDueConvertsToDateOnlyComponents() {
        let snapshot = RemindersSyncItemSnapshot(
            title: "Buy milk",
            isCompleted: false,
            notes: nil,
            due: "2026-07-17"
        )
        #expect(snapshot.dueComponents == DateComponents(year: 2026, month: 7, day: 17))
    }

    @Test func testTimedDueRoundTripsThroughComponents() throws {
        let date = Date(timeIntervalSince1970: 1_784_000_000)
        let snapshot = RemindersSyncItemSnapshot(
            title: "Buy milk",
            isCompleted: false,
            notes: nil,
            due: RemindersSyncItemSnapshot.canonicalDueString(from: date)
        )
        let components = try #require(snapshot.dueComponents)
        #expect(Calendar.current.date(from: components) == date)
    }

    @Test func testParseDueDateTimeAcceptsCommonServerFormats() {
        let expected = Date(timeIntervalSince1970: 1_784_000_000) // 2026-07-14T03:33:20Z
        #expect(RemindersSyncItemSnapshot.parseDueDateTime("2026-07-14T03:33:20+00:00") == expected)
        #expect(RemindersSyncItemSnapshot.parseDueDateTime("2026-07-14T03:33:20.000+00:00") == expected)
        #expect(RemindersSyncItemSnapshot.parseDueDateTime("not a date") == nil)

        // Without an offset the string is interpreted in the current timezone.
        let local = RemindersSyncItemSnapshot.parseDueDateTime("2026-07-13T14:13:20")
        #expect(local != nil)
    }

    @Test func testMalformedDueProducesNoComponents() {
        let snapshot = RemindersSyncItemSnapshot(
            title: "Buy milk",
            isCompleted: false,
            notes: nil,
            due: "2026-07"
        )
        #expect(snapshot.dueComponents == nil)
    }

    // MARK: - Notes normalization

    @Test func testNormalizedNotesTrimsAndCollapsesEmptyToNil() {
        #expect(RemindersSyncItemSnapshot.normalizedNotes(nil) == nil)
        #expect(RemindersSyncItemSnapshot.normalizedNotes("") == nil)
        #expect(RemindersSyncItemSnapshot.normalizedNotes("  \n ") == nil)
        #expect(RemindersSyncItemSnapshot.normalizedNotes(" note \n") == "note")
    }

    // MARK: - Comparing sides

    @Test func testSnapshotsFromBothSidesCompareEqualWhenContentMatches() {
        let fromTodo = RemindersSyncItemSnapshot(todoItem: TodoListItem(
            summary: "Buy milk ",
            uid: "todo-1",
            status: "needs_action",
            description: " same note ",
            dueRaw: "2026-07-17"
        ))
        let fromLink = RemindersSyncItemSnapshot(
            title: "Buy milk",
            isCompleted: false,
            notes: "same note",
            due: "2026-07-17"
        )
        #expect(fromTodo == fromLink)
    }
}
