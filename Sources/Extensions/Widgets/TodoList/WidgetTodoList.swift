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
        .configurationDisplayName("To-do List")
        .description("Check your lists and add items")
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
            TodoListItem(summary: "Milk", uid: "1", status: "needs_action", description: ""),
            TodoListItem(summary: "Bread", uid: "2", status: "needs_action", description: ""),
            TodoListItem(summary: "Eggs", uid: "3", status: "needs_action", description: ""),
        ],
        family: .systemMedium
    )
})

@available(iOS 17, *)
struct WidgetTodoListView: View {
    let serverId: String
    let listId: String
    let title: String
    let items: [TodoListItem]
    let isEmpty: Bool

    private var addItemURL: URL? {
        guard !serverId.isEmpty, !listId.isEmpty else {
            return nil
        }
        return URL(string: "homeassistant://navigate/todo")?.appending(queryItems: [
            URLQueryItem(name: "entity_id", value: listId),
            URLQueryItem(name: "serverId", value: serverId)
        ])
    }

    var body: some View {
        if isEmpty {
            emptyStateView
        } else {
            contentView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Image(systemSymbol: .checklistChecked)
                .font(.system(size: 32))
                .foregroundStyle(.haPrimary)
            Text("To-do List")
                .font(DesignSystem.Font.callout.bold())
            Text("Select a list to display")
                .font(DesignSystem.Font.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: .zero) {
            headerView
            itemsListView
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            Image(.logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .padding(DesignSystem.Spaces.half)
        }
    }

    private var headerView: some View {
        HStack {
            Text(title)
                .font(DesignSystem.Font.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            HStack(spacing: DesignSystem.Spaces.half) {
                Button(intent: TodoListRefreshAppIntent()) {
                    Image(systemSymbol: .arrowClockwiseCircle)
                        .foregroundStyle(.secondary)
                        .font(DesignSystem.Font.title)
                }
                .buttonStyle(.plain)
                if let addItemURL {
                    Link(destination: addItemURL.withWidgetAuthenticity()) {
                        Image(systemSymbol: .plusCircleFill)
                            .foregroundStyle(.haPrimary)
                            .font(DesignSystem.Font.title)
                    }
                } else {
                    Image(systemSymbol: .plusCircleFill)
                        .foregroundStyle(.haPrimary)
                        .font(DesignSystem.Font.title)
                }
            }
        }
        .padding(.bottom, DesignSystem.Spaces.half)
    }

    private var itemsListView: some View {
        VStack(alignment: .leading, spacing: .zero) {
            if items.isEmpty {
                Text("All done! 🎉")
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .frame(height: 40)
            } else {
                ForEach(items, id: \.uid) { item in
                    HStack {
                        Image(systemSymbol: .circle)
                            .font(DesignSystem.Font.body)
                            .foregroundStyle(.haPrimary)
                        Text(item.summary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(height: 32)
                }
            }
        }
    }
}
