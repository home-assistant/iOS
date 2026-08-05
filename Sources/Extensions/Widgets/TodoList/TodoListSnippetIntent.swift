import AppIntents
import Foundation
import Shared

/// Builds the interactive snippet that iOS 26 presents for a to-do list, so items can be added and
/// completed without leaving the current context.
///
/// The system runs this intent again after every interaction with the snippet's buttons, and it may
/// run it extra times on its own (for example when the device switches to dark mode). It therefore
/// only reads state - all mutations live in the intents the snippet's buttons trigger.
@available(iOS 26.0, *)
struct TodoListSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "widgets.todo_list.title"
    static var isDiscoverable: Bool = false

    @Parameter(title: "widgets.todo_list.parameter.server_id")
    var serverId: String

    @Parameter(title: "widgets.todo_list.parameter.list_id")
    var listId: String

    @Parameter(title: "widgets.todo_list.parameter.list")
    var listTitle: String

    init() {
        self.serverId = ""
        self.listId = ""
        self.listTitle = ""
    }

    init(serverId: String, listId: String, listTitle: String) {
        self.serverId = serverId
        self.listId = listId
        self.listTitle = listTitle
    }

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: TodoListSnippetView(
            serverId: serverId,
            listId: listId,
            title: listTitle,
            items: await pendingItems()
        ))
    }

    private func pendingItems() async -> [TodoListItem] {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
              let api = Current.api(for: server) else {
            Current.Log.error("No server found for todo list snippet, serverId: \(serverId)")
            return []
        }

        do {
            return try await api.todoListItems(listId: listId).filter { $0.status == "needs_action" }
        } catch {
            Current.Log.error("Failed to fetch todo items for snippet in list \(listId): \(error)")
            return []
        }
    }
}
