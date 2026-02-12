import Shared
import SwiftUI

@available(iOS 17, *)
struct WidgetTodoListView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let serverId: String
    let listId: String
    let title: String
    let items: [TodoListItem]
    let isEmpty: Bool

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
            Text(verbatim: L10n.Widgets.TodoList.title)
                .font(DesignSystem.Font.callout.bold())
            Text(verbatim: L10n.Widgets.TodoList.selectList)
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
            if widgetFamily == .systemSmall {
                Text(verbatim: title.first.map(String.init) ?? "")
                    .padding(DesignSystem.Spaces.one)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .clipShape(.circle)
                Spacer()
            } else {
                Text(title)
                    .font(DesignSystem.Font.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(spacing: DesignSystem.Spaces.half) {
                Button(intent: TodoListRefreshAppIntent()) {
                    Image(systemSymbol: .arrowClockwiseCircle)
                        .foregroundStyle(.secondary)
                        .font(DesignSystem.Font.title)
                }
                .buttonStyle(.plain)
                if let addItemURL = AppConstants.todoListAddItemURL(listId: listId, serverId: serverId) {
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
                Text(verbatim: L10n.Widgets.TodoList.allDone)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .frame(height: 40)
            } else {
                ForEach(items, id: \.uid) { item in
                    Button(intent: TodoItemCompleteAppIntent(
                        serverId: serverId,
                        listId: listId,
                        itemId: item.uid
                    )) {
                        HStack {
                            Image(systemSymbol: .circle)
                                .font(DesignSystem.Font.body)
                                .foregroundStyle(.haPrimary)
                            Text(item.summary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
