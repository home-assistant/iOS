@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import WidgetKit

/// Renders the to-do widget's drawing at the families it supports, in light and dark.
///
/// Most of these are the small family, which draws its rows at the medium family's size and so
/// has room for only two of them. The medium one is here to compare against: the rows should look
/// the same size in both.
struct WidgetTodoListContentViewSnapshotTests {
    private static let strings = WidgetTodoListStrings(
        title: "To-do list",
        selectList: "Select a list",
        allDone: "All done!"
    )

    private static let listURL = URL(string: "https://example.com/todo")!

    private static let items: [WidgetTodoItemModel] = [
        .init(id: "todo-0", summary: "Coffee beans"),
        .init(id: "todo-1", summary: "Book a table", dueText: "Tomorrow"),
        .init(id: "todo-2", summary: "Water the plants", dueText: "Yesterday", isOverdue: true),
        .init(id: "todo-3", summary: "Replace the filter", dueText: "Next week"),
        .init(id: "todo-4", summary: "Call the plumber"),
        .init(id: "todo-5", summary: "Pay the electricity bill", dueText: "Today"),
    ]

    /// Handed all six items, the small family draws the first two.
    @available(iOS 17, *)
    @MainActor @Test func systemSmallSnapshot() {
        assertTodoListSnapshot(family: .systemSmall, items: Self.items)
    }

    /// A summary with no due date wraps onto a second line; one with a due date keeps to a single
    /// line, since the date is its second.
    @available(iOS 17, *)
    @MainActor @Test func systemSmallLongSummariesSnapshot() {
        assertTodoListSnapshot(family: .systemSmall, items: [
            .init(id: "long-0", summary: "Pick up the dry cleaning before the shop closes"),
            .init(
                id: "long-1",
                summary: "Renew the car insurance policy online",
                dueText: "Yesterday",
                isOverdue: true
            ),
        ])
    }

    /// The tallest the small family gets: two summaries wrapping onto a second line each.
    @available(iOS 17, *)
    @MainActor @Test func systemSmallTwoWrappedSummariesSnapshot() {
        assertTodoListSnapshot(family: .systemSmall, items: [
            .init(id: "wrap-0", summary: "Pick up the dry cleaning before the shop closes"),
            .init(id: "wrap-1", summary: "Take the recycling out to the kerb tonight"),
        ])
    }

    @available(iOS 17, *)
    @MainActor @Test func systemSmallAllDoneSnapshot() {
        assertTodoListSnapshot(family: .systemSmall, items: [])
    }

    @available(iOS 17, *)
    @MainActor @Test func systemSmallNotConfiguredSnapshot() {
        assertTodoListSnapshot(family: .systemSmall, items: [], isConfigured: false)
    }

    @available(iOS 17, *)
    @MainActor @Test func systemMediumSnapshot() {
        assertTodoListSnapshot(family: .systemMedium, items: Self.items)
    }

    /// The controls wrapped the way the widget wraps them — a button completes an item, a link opens
    /// the list — which must not move the checkbox off the summary's first line.
    @available(iOS 17, *)
    @MainActor @Test func systemMediumWithControlsSnapshot() {
        assertTodoListSnapshot(family: .systemMedium, items: Self.items, wrapsControls: true)
    }

    @available(iOS 17, *)
    @MainActor @Test func systemLargeSnapshot() {
        assertTodoListSnapshot(family: .systemLarge, items: Self.items)
    }

    /// The shortest large widget, 321pt on a 4.7" phone, has no room for a sixth whole row, so the list
    /// leaves it off rather than cutting it in half.
    @available(iOS 17, *)
    @MainActor @Test func systemLargeShortSnapshot() {
        assertTodoListSnapshot(family: .systemLarge, items: Self.items, size: CGSize(width: 321, height: 321))
    }

    @available(iOS 17, *)
    @MainActor private func assertTodoListSnapshot(
        family: WidgetFamily,
        items: [WidgetTodoItemModel],
        isConfigured: Bool = true,
        // Overrides the family's usual size, for the cases that only go wrong on a smaller phone.
        size: CGSize? = nil,
        wrapsControls: Bool = false,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = size ?? Self.size(for: family)
        assertLightDarkSnapshots(
            of: WidgetTodoListContentView(
                title: "Groceries",
                items: items,
                isConfigured: isConfigured,
                family: family,
                strings: Self.strings,
                completeControl: { _, control in
                    wrapsControls ? AnyView(Button {} label: { control }.buttonStyle(.plain)) : control
                },
                itemContent: { _, content in
                    wrapsControls ? AnyView(Link(destination: Self.listURL) { content }) : content
                }
            )
            .padding(DesignSystem.Spaces.two)
            .background(Color(uiColor: .systemBackground)),
            layout: .fixed(width: size.width, height: size.height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    /// The home screen widget sizes on a current iPhone, so a layout that only just fits here only
    /// just fits on device too.
    private static func size(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall:
            CGSize(width: 170, height: 170)
        case .systemMedium:
            CGSize(width: 364, height: 170)
        default:
            CGSize(width: 364, height: 382)
        }
    }
}
