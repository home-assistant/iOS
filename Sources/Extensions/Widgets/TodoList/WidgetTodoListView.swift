import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetTodoListView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    private static let minuteFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let namedRelativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter
    }()

    private static let numericRelativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        return formatter
    }()

    let serverId: String
    let listId: String
    let title: String
    let items: [TodoListItem]
    let isEmpty: Bool

    var body: some View {
        WidgetTodoListContentView(
            title: title,
            items: items.map(designSystemModel(for:)),
            isConfigured: !isEmpty,
            family: widgetFamily,
            strings: .init(
                title: L10n.Widgets.TodoList.title,
                selectList: L10n.Widgets.TodoList.selectList,
                allDone: L10n.Widgets.TodoList.allDone
            ),
            logo: Image(.logo),
            refreshControl: { label in
                AnyView(
                    Button(intent: TodoListRefreshAppIntent()) {
                        label
                    }
                    .buttonStyle(.plain)
                )
            },
            addControl: { label in
                guard let addItemURL = AppConstants.todoListAddItemURL(listId: listId, serverId: serverId) else {
                    return AnyView(label)
                }
                return AnyView(Link(destination: addItemURL.withWidgetAuthenticity()) { label })
            },
            completeControl: { item, control in
                AnyView(
                    Button(intent: TodoItemCompleteAppIntent(
                        serverId: serverId,
                        listId: listId,
                        itemId: item.id
                    )) {
                        control
                    }
                    .buttonStyle(.plain)
                )
            },
            itemContent: { _, content in
                guard let openListURL = AppConstants.todoListOpenURL(listId: listId, serverId: serverId) else {
                    return AnyView(EmptyView())
                }
                return AnyView(Link(destination: openListURL.withWidgetAuthenticity()) { content })
            }
        )
    }

    /// The drawing half of an item: what it says and, in words, when it is due.
    private func designSystemModel(for item: TodoListItem) -> WidgetTodoItemModel {
        let due = dueDisplay(for: item)
        return .init(
            id: item.uid,
            summary: item.summary,
            dueText: due?.text,
            isOverdue: due?.isPastDateOnly ?? false
        )
    }

    struct DueDisplay {
        let text: String
        let isPastDateOnly: Bool
    }

    // Internal for testing purposes
    func dueDisplay(for item: TodoListItem) -> DueDisplay? {
        guard let due = item.due else { return nil }
        let now = Date()
        if item.hasDueTime {
            // Check if the time difference is less than 1 hour
            let timeInterval = due.timeIntervalSince(now)
            let hourInSeconds: TimeInterval = 3600

            // Use "Now" for times within 1 minute
            if abs(timeInterval) < 60 {
                return DueDisplay(text: L10n.Widgets.TodoList.DueDate.now, isPastDateOnly: false)
            }

            if abs(timeInterval) < hourInSeconds {
                // Calculate minutes for times within 1 hour
                let minutes: Int
                if timeInterval > 0 {
                    minutes = Int(ceil(timeInterval / 60))
                } else {
                    minutes = Int(floor(timeInterval / 60))
                }

                // Use DateComponentsFormatter for proper localization
                let absMinutes = abs(minutes)
                if let formattedMinutes = Self.minuteFormatter.string(from: TimeInterval(absMinutes * 60)) {
                    let text = minutes > 0
                        ? L10n.Widgets.TodoList.DueDate.inFormat(formattedMinutes)
                        : L10n.Widgets.TodoList.DueDate.agoFormat(capitalizeLeadingCharacter(in: formattedMinutes))
                    return DueDisplay(text: text, isPastDateOnly: false)
                }
            }

            let text = Self.numericRelativeFormatter.localizedString(for: due, relativeTo: now)
            return DueDisplay(text: capitalizeLeadingCharacter(in: text), isPastDateOnly: false)
        }

        let calendar = Current.calendar()
        if calendar.isDateInToday(due) {
            return DueDisplay(text: L10n.Widgets.TodoList.DueDate.today, isPastDateOnly: false)
        }

        let dueAtNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: due) ?? due
        let nowAtNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let text = Self.namedRelativeFormatter.localizedString(for: dueAtNoon, relativeTo: nowAtNoon)
        let isPastDateOnly = dueAtNoon < nowAtNoon
        return DueDisplay(text: capitalizeLeadingCharacter(in: text), isPastDateOnly: isPastDateOnly)
    }

    private func capitalizeLeadingCharacter(in text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }
}

@available(iOS 17, *)
private enum WidgetTodoListPreviewSample {
    /// A mix of the three row shapes: no due date, one still to come, and one already past — which
    /// is the only one drawn in orange.
    static func items(now: Date = Date()) -> [TodoListItem] {
        [
            .init(summary: "Coffee beans", uid: "preview-0", status: "needs_action", description: nil),
            .init(
                summary: "Book a table",
                uid: "preview-1",
                status: "needs_action",
                description: nil,
                dueRaw: "2026-01-01",
                due: now.addingTimeInterval(24 * 60 * 60)
            ),
            .init(
                summary: "Water the plants",
                uid: "preview-2",
                status: "needs_action",
                description: nil,
                dueRaw: "2026-01-01",
                due: now.addingTimeInterval(-24 * 60 * 60)
            ),
        ]
    }

    static func entry(family: WidgetFamily, configured: Bool = true) -> WidgetTodoListEntry {
        WidgetTodoListEntry(
            date: Date(),
            serverId: "preview-server",
            listId: configured ? "preview-list" : "",
            listTitle: "Groceries",
            items: configured ? items() : [],
            family: family
        )
    }
}

@available(iOS 17, *)
#Preview("Medium", as: .systemMedium, widget: {
    WidgetTodoList()
}, timeline: {
    WidgetTodoListPreviewSample.entry(family: .systemMedium)
})

@available(iOS 17, *)
#Preview("Small", as: .systemSmall, widget: {
    WidgetTodoList()
}, timeline: {
    WidgetTodoListPreviewSample.entry(family: .systemSmall)
})

// No list picked yet: the prompt rather than the list.
@available(iOS 17, *)
#Preview("Not configured", as: .systemMedium, widget: {
    WidgetTodoList()
}, timeline: {
    WidgetTodoListPreviewSample.entry(family: .systemMedium, configured: false)
})
