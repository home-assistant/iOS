import Intents
import Shared
import SwiftUI
import WidgetKit
import AppIntents

@available(iOS 17, *)
struct WidgetTodoList: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.todoList.rawValue,
            provider: WidgetTodoListAppIntentTimelineProvider()
        ) { timelineEntry in
            WidgetTodoListView(
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
    let title: String
    let items: [TodoListItem]
    let isEmpty: Bool

    var body: some View {
        if isEmpty {
            WidgetEmptyView(message: "Select a to-do list")
        } else {
            contentView
        }
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
                Image(systemSymbol: .arrowClockwiseCircle)
                    .foregroundStyle(.secondary)
                    .font(DesignSystem.Font.title)
                Image(systemSymbol: .plusCircleFill)
                    .foregroundStyle(.haPrimary)
                    .font(DesignSystem.Font.title)
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
