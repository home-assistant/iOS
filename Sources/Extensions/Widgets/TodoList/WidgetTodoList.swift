import AppIntents
import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetTodoList: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.todoList.rawValue,
            provider: WidgetTodoListAppIntentTimelineProvider()
        ) { timelineEntry in
            WidgetTodoListView(
                serverId: timelineEntry.serverId,
                listId: timelineEntry.listId,
                title: timelineEntry.listTitle,
                items: timelineEntry.items,
                isEmpty: timelineEntry.listId.isEmpty
            )
            .widgetBackground(.primaryBackground)
        }
        .configurationDisplayName(L10n.Widgets.TodoList.title)
        .description(L10n.Widgets.TodoList.description)
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        [.systemSmall, .systemMedium, .systemLarge]
    }
}

@available(iOS 17, *)
#Preview(as: .systemMedium, widget: {
    WidgetTodoList()
}, timeline: {
    WidgetTodoListEntry(
        date: Date(),
        serverId: "server-id",
        listId: "todo.shopping",
        listTitle: "Shopping List",
        items: [
            TodoListItem(
                summary: "Milk",
                uid: "1",
                status: "needs_action",
                description: "",
                due: Date()
            ),
            TodoListItem(summary: "Bread", uid: "2", status: "needs_action", description: ""),
            TodoListItem(
                summary: "Eggs",
                uid: "3",
                status: "needs_action",
                description: "",
                due: Date()
            ),
        ],
        family: .systemMedium
    )
})

@available(iOS 17, *)
#Preview(as: .systemSmall, widget: {
    WidgetTodoList()
}, timeline: {
    WidgetTodoListEntry(
        date: Date(),
        serverId: "server-id",
        listId: "todo.shopping",
        listTitle: "Shopping List",
        items: [
            TodoListItem(
                summary: "Milk",
                uid: "1",
                status: "needs_action",
                description: "",
                due: Date()
            ),
            TodoListItem(summary: "Bread", uid: "2", status: "needs_action", description: ""),
            TodoListItem(
                summary: "Eggs",
                uid: "3",
                status: "needs_action",
                description: "",
                due: Date()
            ),
        ],
        family: .systemMedium
    )
})

@available(iOS 17, *)
#Preview(as: .systemLarge, widget: {
    WidgetTodoList()
}, timeline: {
    WidgetTodoListEntry(
        date: Date(),
        serverId: "server-id",
        listId: "todo.shopping",
        listTitle: "Shopping List",
        items: [
            TodoListItem(
                summary: "Milk",
                uid: "1",
                status: "needs_action",
                description: "",
                due: Date()
            ),
            TodoListItem(summary: "Bread", uid: "2", status: "needs_action", description: ""),
            TodoListItem(
                summary: "Eggs",
                uid: "3",
                status: "needs_action",
                description: "",
                due: Date()
            ),
        ],
        family: .systemMedium
    )
})
@available(iOS 17, *)
#Preview(as: .systemSmall, widget: {
    WidgetTodoList()
}, timeline: {
    WidgetTodoListEntry(
        date: Date(),
        serverId: "server-id",
        listId: "todo.shopping",
        listTitle: "Shopping List",
        items: [
            TodoListItem(
                summary: "Milk",
                uid: "1",
                status: "needs_action",
                description: ""
            ),
            TodoListItem(summary: "Bread", uid: "2", status: "needs_action", description: ""),
            TodoListItem(
                summary: "Eggs",
                uid: "3",
                status: "needs_action",
                description: ""
            ),
        ],
        family: .systemMedium
    )
})
