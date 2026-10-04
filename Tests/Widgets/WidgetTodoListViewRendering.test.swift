@testable import HomeAssistant
import Shared
import SwiftUI
import WidgetKit
import XCTest

/// Draws the to-do list widget in each state and family it supports, and checks how a date-only
/// due date reads. The assertions on the drawn view are deliberately cheap: what matters here is
/// that every row shape builds; the look is covered by the design system's own snapshots.
@available(iOS 17, *)
@MainActor
final class WidgetTodoListViewRenderingTests: XCTestCase {
    func testListRendersInEveryFamily() {
        let now = Date()
        let items = [
            TodoListItem(summary: "Coffee beans", uid: "0", status: "needs_action", description: nil),
            TodoListItem(
                summary: "Book a table",
                uid: "1",
                status: "needs_action",
                description: nil,
                dueRaw: "2026-01-01",
                due: now.addingTimeInterval(3 * 24 * 60 * 60)
            ),
            TodoListItem(
                summary: "Water the plants",
                uid: "2",
                status: "needs_action",
                description: nil,
                dueRaw: "2026-01-01",
                due: now.addingTimeInterval(-3 * 24 * 60 * 60)
            ),
            TodoListItem(
                summary: "Call back",
                uid: "3",
                status: "needs_action",
                description: nil,
                dueRaw: "2026-01-01T10:00:00",
                due: now.addingTimeInterval(20 * 60)
            ),
        ]
        let view = WidgetTodoListView(
            serverId: "server",
            listId: "todo.groceries",
            title: "Groceries",
            items: items,
            isEmpty: false
        )

        for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge] {
            XCTAssertTrue(render(view, family: family))
        }
    }

    func testEmptyAndUnconfiguredStatesRender() {
        let allDone = WidgetTodoListView(
            serverId: "server",
            listId: "todo.groceries",
            title: "Groceries",
            items: [],
            isEmpty: false
        )
        let unconfigured = WidgetTodoListView(serverId: "", listId: "", title: "", items: [], isEmpty: true)

        XCTAssertTrue(render(allDone, family: .systemMedium))
        XCTAssertTrue(render(unconfigured, family: .systemSmall))
    }

    func testItemWithoutDueDateHasNoDueDisplay() {
        let item = TodoListItem(summary: "No date", uid: "0", status: "needs_action", description: nil)

        XCTAssertNil(Self.view.dueDisplay(for: item))
    }

    func testDateOnlyItemDueTodayReadsToday() {
        let calendar = Current.calendar()
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
        let item = TodoListItem(
            summary: "Today",
            uid: "0",
            status: "needs_action",
            description: nil,
            dueRaw: "2026-01-01",
            due: noon
        )

        let display = Self.view.dueDisplay(for: item)

        XCTAssertEqual(display?.text, L10n.Widgets.TodoList.DueDate.today)
        XCTAssertEqual(display?.isPastDateOnly, false)
    }

    /// A date-only item from days ago is the one drawn as overdue; one days ahead is not.
    func testDateOnlyItemsInThePastAreOverdue() throws {
        let past = TodoListItem(
            summary: "Past",
            uid: "0",
            status: "needs_action",
            description: nil,
            dueRaw: "2026-01-01",
            due: Date().addingTimeInterval(-5 * 24 * 60 * 60)
        )
        let future = TodoListItem(
            summary: "Future",
            uid: "1",
            status: "needs_action",
            description: nil,
            dueRaw: "2026-01-01",
            due: Date().addingTimeInterval(5 * 24 * 60 * 60)
        )

        let pastDisplay = try XCTUnwrap(Self.view.dueDisplay(for: past))
        let futureDisplay = try XCTUnwrap(Self.view.dueDisplay(for: future))

        XCTAssertTrue(pastDisplay.isPastDateOnly)
        XCTAssertFalse(futureDisplay.isPastDateOnly)
        XCTAssertFalse(pastDisplay.text.isEmpty)
        XCTAssertEqual(String(pastDisplay.text.prefix(1)), pastDisplay.text.prefix(1).uppercased())
        XCTAssertNotEqual(pastDisplay.text, futureDisplay.text)
    }

    /// A timed item hours away reads as a relative time, and is never marked as an overdue date.
    func testTimedItemHoursAwayUsesRelativeTime() throws {
        let item = TodoListItem(
            summary: "Later",
            uid: "0",
            status: "needs_action",
            description: nil,
            dueRaw: "2026-01-01T10:00:00",
            due: Date().addingTimeInterval(-5 * 60 * 60)
        )

        let display = try XCTUnwrap(Self.view.dueDisplay(for: item))

        XCTAssertFalse(display.isPastDateOnly)
        XCTAssertFalse(display.text.isEmpty)
        XCTAssertNotEqual(display.text, L10n.Widgets.TodoList.DueDate.now)
    }

    // MARK: - Helpers

    private static let view = WidgetTodoListView(
        serverId: "server",
        listId: "todo.list",
        title: "List",
        items: [],
        isEmpty: false
    )

    /// Hosts the view in a window at a widget's size so `body` and its rows are built. The window
    /// never becomes key: the snapshot helpers draw into whatever window is key.
    private func render(_ view: WidgetTodoListView, family: WidgetFamily) -> Bool {
        let host = UIHostingController(rootView: view.environment(\.widgetFamily, family))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 364, height: 382))
        window.rootViewController = host
        window.isHidden = false
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let size = host.sizeThatFits(in: CGSize(width: 364, height: 382))
        window.isHidden = true
        window.rootViewController = nil
        return size.width > 0 && size.height > 0
    }
}
