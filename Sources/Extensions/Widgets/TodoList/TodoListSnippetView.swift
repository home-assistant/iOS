import AppIntents
import SFSafeSymbols
import Shared
import SwiftUI

/// Contents of the interactive snippet `TodoListSnippetIntent` returns.
///
/// Snippets render out of process like widgets do, so every control has to be backed by an App
/// Intent - local `@State` never reaches this view. After a button runs its intent the system
/// discards these views and asks `TodoListSnippetIntent` for a freshly rendered copy.
@available(iOS 26.0, *)
struct TodoListSnippetView: View {
    /// Apple asks snippets to stay under 340pt tall, so long lists are truncated with a counter.
    static let maximumVisibleItems = 5

    let serverId: String
    let listId: String
    let title: String
    let items: [TodoListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            HStack(spacing: DesignSystem.Spaces.one) {
                Image(systemSymbol: .checklistChecked)
                    .font(DesignSystem.Font.title3)
                    .foregroundStyle(.haPrimary)
                Text(title)
                    .font(DesignSystem.Font.title3.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(.logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            }
            if items.isEmpty {
                Text(verbatim: L10n.Widgets.TodoList.allDone)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.oneAndHalf) {
                    ForEach(items.prefix(Self.maximumVisibleItems), id: \.uid) { item in
                        HStack(spacing: DesignSystem.Spaces.one) {
                            Button(intent: TodoItemCompleteAppIntent(
                                serverId: serverId,
                                listId: listId,
                                itemId: item.uid
                            )) {
                                Image(systemSymbol: .circle)
                                    .font(DesignSystem.Font.title3)
                                    .foregroundStyle(.haPrimary)
                            }
                            .buttonStyle(.plain)
                            Text(item.summary)
                                .font(DesignSystem.Font.body)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                    }
                    if items.count > Self.maximumVisibleItems {
                        Text(verbatim: L10n.Widgets.TodoList.Snippet.moreItems(items.count - Self.maximumVisibleItems))
                            .font(DesignSystem.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: DesignSystem.Spaces.one) {
                Button(intent: TodoListAddItemAppIntent(
                    serverId: serverId,
                    listId: listId,
                    listTitle: title
                )) {
                    Label(L10n.Widgets.TodoList.Snippet.addAnother, systemSymbol: .plusCircleFill)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                if let openListURL = AppConstants.todoListOpenURL(listId: listId, serverId: serverId) {
                    Button(intent: OpenURLIntent(openListURL.withWidgetAuthenticity())) {
                        Label(
                            L10n.Widgets.TodoList.Snippet.openList,
                            systemSymbol: .arrowUpForwardSquare
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(DesignSystem.Spaces.two)
    }
}

@available(iOS 26.0, *)
#Preview {
    TodoListSnippetView(
        serverId: "server-id",
        listId: "todo.shopping",
        title: "Shopping List",
        items: [
            TodoListItem(summary: "Milk", uid: "1", status: "needs_action", description: ""),
            TodoListItem(summary: "Bread", uid: "2", status: "needs_action", description: ""),
            TodoListItem(summary: "Eggs", uid: "3", status: "needs_action", description: ""),
        ]
    )
}

@available(iOS 26.0, *)
#Preview("All done") {
    TodoListSnippetView(
        serverId: "server-id",
        listId: "todo.shopping",
        title: "Shopping List",
        items: []
    )
}
