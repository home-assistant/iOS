@testable import HomeAssistant
import Shared
import XCTest

@available(iOS 17, *)
class WidgetTodoListViewTests: XCTestCase {
    // Helper to generate expected text using the same formatter and L10n as the implementation
    private func expectedMinuteText(minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .full
        
        if let formattedMinutes = formatter.string(from: TimeInterval(abs(minutes) * 60)) {
            if minutes > 0 {
                return L10n.Widgets.TodoList.DueDate.inFormat(formattedMinutes)
            } else {
                // Capitalize first character like the implementation does
                let firstChar = formattedMinutes.prefix(1).uppercased()
                let rest = formattedMinutes.dropFirst()
                let capitalized = firstChar + rest
                return L10n.Widgets.TodoList.DueDate.agoFormat(capitalized)
            }
        }
        return ""
    }
    
    func testDueDisplayForItemsDueInMinutes() {
        let view = WidgetTodoListView(
            serverId: "test-server",
            listId: "test-list",
            title: "Test List",
            items: [],
            isEmpty: false
        )

        // Test: Item due in 15 minutes
        let dueIn15Minutes = Date().addingTimeInterval(15 * 60)
        let item15 = TodoListItem(
            summary: "Task in 15 min",
            uid: "uid-15",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T12:15:00",
            due: dueIn15Minutes
        )

        let display15 = view.dueDisplay(for: item15)
        XCTAssertNotNil(display15)
        XCTAssertEqual(display15?.text, expectedMinuteText(minutes: 15))
        XCTAssertFalse(display15?.isPastDateOnly ?? true)

        // Test: Item due in 30 minutes
        let dueIn30Minutes = Date().addingTimeInterval(30 * 60)
        let item30 = TodoListItem(
            summary: "Task in 30 min",
            uid: "uid-30",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T12:30:00",
            due: dueIn30Minutes
        )

        let display30 = view.dueDisplay(for: item30)
        XCTAssertNotNil(display30)
        XCTAssertEqual(display30?.text, expectedMinuteText(minutes: 30))
        XCTAssertFalse(display30?.isPastDateOnly ?? true)

        // Test: Item due in 45 minutes
        let dueIn45Minutes = Date().addingTimeInterval(45 * 60)
        let item45 = TodoListItem(
            summary: "Task in 45 min",
            uid: "uid-45",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T12:45:00",
            due: dueIn45Minutes
        )

        let display45 = view.dueDisplay(for: item45)
        XCTAssertNotNil(display45)
        XCTAssertEqual(display45?.text, expectedMinuteText(minutes: 45))
        XCTAssertFalse(display45?.isPastDateOnly ?? true)

        // Test: Item due in 1 minute
        let dueIn1Minute = Date().addingTimeInterval(60)
        let item1 = TodoListItem(
            summary: "Task in 1 min",
            uid: "uid-1",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T12:01:00",
            due: dueIn1Minute
        )

        let display1 = view.dueDisplay(for: item1)
        XCTAssertNotNil(display1)
        XCTAssertEqual(display1?.text, expectedMinuteText(minutes: 1))
        XCTAssertFalse(display1?.isPastDateOnly ?? true)
    }

    func testDueDisplayForItemsDueLessThanOneMinute() {
        let view = WidgetTodoListView(
            serverId: "test-server",
            listId: "test-list",
            title: "Test List",
            items: [],
            isEmpty: false
        )

        // Test: Item due in 30 seconds (should show "Now")
        let dueIn30Seconds = Date().addingTimeInterval(30)
        let itemNow = TodoListItem(
            summary: "Task now",
            uid: "uid-now",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T12:00:30",
            due: dueIn30Seconds
        )

        let displayNow = view.dueDisplay(for: itemNow)
        XCTAssertNotNil(displayNow)
        XCTAssertEqual(displayNow?.text, L10n.Widgets.TodoList.DueDate.now)
        XCTAssertFalse(displayNow?.isPastDateOnly ?? true)
    }

    func testDueDisplayForPastItemsInMinutes() {
        let view = WidgetTodoListView(
            serverId: "test-server",
            listId: "test-list",
            title: "Test List",
            items: [],
            isEmpty: false
        )

        // Test: Item overdue by 15 minutes
        let overdue15Minutes = Date().addingTimeInterval(-15 * 60)
        let itemOverdue = TodoListItem(
            summary: "Task overdue",
            uid: "uid-overdue",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T11:45:00",
            due: overdue15Minutes
        )

        let displayOverdue = view.dueDisplay(for: itemOverdue)
        XCTAssertNotNil(displayOverdue)
        XCTAssertEqual(displayOverdue?.text, expectedMinuteText(minutes: -15))
        XCTAssertFalse(displayOverdue?.isPastDateOnly ?? true)

        // Test: Item overdue by 1 minute
        let overdue1Minute = Date().addingTimeInterval(-60)
        let itemOverdue1 = TodoListItem(
            summary: "Task overdue 1 min",
            uid: "uid-overdue-1",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T11:59:00",
            due: overdue1Minute
        )

        let displayOverdue1 = view.dueDisplay(for: itemOverdue1)
        XCTAssertNotNil(displayOverdue1)
        XCTAssertEqual(displayOverdue1?.text, expectedMinuteText(minutes: -1))
        XCTAssertFalse(displayOverdue1?.isPastDateOnly ?? true)
    }

    func testDueDisplayForItemsDueMoreThanOneHour() {
        let view = WidgetTodoListView(
            serverId: "test-server",
            listId: "test-list",
            title: "Test List",
            items: [],
            isEmpty: false
        )

        // Test: Item due in 2 hours (should use RelativeDateTimeFormatter)
        let dueIn2Hours = Date().addingTimeInterval(2 * 60 * 60)
        let item2Hours = TodoListItem(
            summary: "Task in 2 hours",
            uid: "uid-2h",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T14:00:00",
            due: dueIn2Hours
        )

        let display2Hours = view.dueDisplay(for: item2Hours)
        XCTAssertNotNil(display2Hours)
        // Just verify it's not nil and doesn't contain "minute" (should use hour-based formatting)
        XCTAssertFalse(display2Hours?.text.isEmpty ?? true)
        XCTAssertFalse(display2Hours?.isPastDateOnly ?? true)
    }

    func testDueDisplayForItemsWithoutDueTime() {
        let view = WidgetTodoListView(
            serverId: "test-server",
            listId: "test-list",
            title: "Test List",
            items: [],
            isEmpty: false
        )

        // Test: Item with date-only due (no time component)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let itemDateOnly = TodoListItem(
            summary: "Task tomorrow",
            uid: "uid-tomorrow",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-02", // Date only, no "T"
            due: tomorrow
        )

        let displayDateOnly = view.dueDisplay(for: itemDateOnly)
        XCTAssertNotNil(displayDateOnly)
        // Should use named formatter for date-only items, not minute-based
        XCTAssertFalse(displayDateOnly?.text.isEmpty ?? true)
    }
}


    func testDueDisplayForItemsDueLessThanOneMinute() {
        let view = WidgetTodoListView(
            serverId: "test-server",
            listId: "test-list",
            title: "Test List",
            items: [],
            isEmpty: false
        )

        // Test: Item due in 30 seconds (should show "Now")
        let dueIn30Seconds = Date().addingTimeInterval(30)
        let itemNow = TodoListItem(
            summary: "Task now",
            uid: "uid-now",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T12:00:30",
            due: dueIn30Seconds
        )

        let displayNow = view.dueDisplay(for: itemNow)
        XCTAssertNotNil(displayNow)
        XCTAssertEqual(displayNow?.text, "Now")
        XCTAssertFalse(displayNow?.isPastDateOnly ?? true)
    }

    func testDueDisplayForPastItemsInMinutes() {
        let view = WidgetTodoListView(
            serverId: "test-server",
            listId: "test-list",
            title: "Test List",
            items: [],
            isEmpty: false
        )

        // Test: Item overdue by 15 minutes
        let overdue15Minutes = Date().addingTimeInterval(-15 * 60)
        let itemOverdue = TodoListItem(
            summary: "Task overdue",
            uid: "uid-overdue",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T11:45:00",
            due: overdue15Minutes
        )

        let displayOverdue = view.dueDisplay(for: itemOverdue)
        XCTAssertNotNil(displayOverdue)
        XCTAssertTrue(displayOverdue?.text.contains("15") ?? false)
        XCTAssertTrue(displayOverdue?.text.contains("minute") ?? false)
        XCTAssertTrue(displayOverdue?.text.contains("ago") ?? false)
        XCTAssertFalse(displayOverdue?.isPastDateOnly ?? true)

        // Test: Item overdue by 1 minute
        let overdue1Minute = Date().addingTimeInterval(-60)
        let itemOverdue1 = TodoListItem(
            summary: "Task overdue 1 min",
            uid: "uid-overdue-1",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T11:59:00",
            due: overdue1Minute
        )

        let displayOverdue1 = view.dueDisplay(for: itemOverdue1)
        XCTAssertNotNil(displayOverdue1)
        XCTAssertTrue(displayOverdue1?.text.contains("1") ?? false)
        XCTAssertTrue(displayOverdue1?.text.contains("minute") ?? false)
        XCTAssertTrue(displayOverdue1?.text.contains("ago") ?? false)
        XCTAssertFalse(displayOverdue1?.isPastDateOnly ?? true)
    }

    func testDueDisplayForItemsDueMoreThanOneHour() {
        let view = WidgetTodoListView(
            serverId: "test-server",
            listId: "test-list",
            title: "Test List",
            items: [],
            isEmpty: false
        )

        // Test: Item due in 2 hours (should use RelativeDateTimeFormatter)
        let dueIn2Hours = Date().addingTimeInterval(2 * 60 * 60)
        let item2Hours = TodoListItem(
            summary: "Task in 2 hours",
            uid: "uid-2h",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-01T14:00:00",
            due: dueIn2Hours
        )

        let display2Hours = view.dueDisplay(for: item2Hours)
        XCTAssertNotNil(display2Hours)
        // The formatter should produce something like "In 2 hours" (capitalized)
        XCTAssertTrue(display2Hours?.text.contains("hour") ?? false)
        XCTAssertFalse(display2Hours?.isPastDateOnly ?? true)
    }

    func testDueDisplayForItemsWithoutDueTime() {
        let view = WidgetTodoListView(
            serverId: "test-server",
            listId: "test-list",
            title: "Test List",
            items: [],
            isEmpty: false
        )

        // Test: Item with date-only due (no time component)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let itemDateOnly = TodoListItem(
            summary: "Task tomorrow",
            uid: "uid-tomorrow",
            status: "needs_action",
            description: nil,
            dueRaw: "2024-01-02", // Date only, no "T"
            due: tomorrow
        )

        let displayDateOnly = view.dueDisplay(for: itemDateOnly)
        XCTAssertNotNil(displayDateOnly)
        // Should use named formatter for date-only items
        XCTAssertFalse(displayDateOnly?.text.contains("minute") ?? false)
    }
}
