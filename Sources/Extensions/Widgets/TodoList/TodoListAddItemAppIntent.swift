import AppIntents
import Foundation
import Shared
import WidgetKit

/// Adds an item to a to-do list and shows the updated list as an interactive snippet.
///
/// This backs the "+" button of the to-do list widget on iOS 26. The system asks for the item's
/// text, the item is created on the server, and `TodoListSnippetIntent` then renders the refreshed
/// list right there - the app never has to open.
///
/// Not every surface can ask someone for text (a widget can't resolve parameters on its own, for
/// instance). When the request fails, the intent falls back to the deep link that opens the list in
/// the app, which is what every iOS version did before interactive snippets existed.
@available(iOS 26.0, *)
struct TodoListAddItemAppIntent: AppIntent {
    static let title: LocalizedStringResource = "widgets.todo_list.add_item_title"
    static var isDiscoverable: Bool = false

    @Parameter(title: "widgets.todo_list.parameter.server_id")
    var serverId: String

    @Parameter(title: "widgets.todo_list.parameter.list_id")
    var listId: String

    @Parameter(title: "widgets.todo_list.parameter.list")
    var listTitle: String

    @Parameter(title: "widgets.todo_list.parameter.summary", default: "")
    var summary: String

    init() {
        self.serverId = ""
        self.listId = ""
        self.listTitle = ""
        self.summary = ""
    }

    init(serverId: String, listId: String, listTitle: String) {
        self.serverId = serverId
        self.listId = listId
        self.listTitle = listTitle
        self.summary = ""
    }

    func perform() async throws -> some IntentResult & OpensIntent & ShowsSnippetIntent {
        let snippetIntent = TodoListSnippetIntent(
            serverId: serverId,
            listId: listId,
            listTitle: listTitle
        )

        let itemSummary: String
        do {
            itemSummary = try await requestedSummary()
        } catch is CancellationError {
            return .result(snippetIntent: snippetIntent)
        } catch {
            Current.Log.error("Could not ask for a new item in list \(listId), opening the app instead: \(error)")
            guard let addItemURL = AppConstants.todoListAddItemURL(listId: listId, serverId: serverId) else {
                return .result(snippetIntent: snippetIntent)
            }
            return .result(
                opensIntent: OpenURLIntent(addItemURL.withWidgetAuthenticity()),
                snippetIntent: snippetIntent
            )
        }

        guard !itemSummary.isEmpty else {
            return .result(snippetIntent: snippetIntent)
        }

        await addItem(summary: itemSummary)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.todoList.rawValue)
        return .result(snippetIntent: snippetIntent)
    }

    /// Text the caller already supplied (a shortcut, for example) wins; otherwise the system asks for it.
    private func requestedSummary() async throws -> String {
        let providedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard providedSummary.isEmpty else { return providedSummary }

        let requestedSummary = try await $summary
            .requestValue(IntentDialog(LocalizedStringResource("widgets.todo_list.add_item_prompt")))
        return requestedSummary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addItem(summary: String) async {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
              let api = Current.api(for: server) else {
            Current.Log.error("No server found for adding todo item, serverId: \(serverId)")
            return
        }

        do {
            try await api.addTodoItem(
                listId: listId,
                summary: summary,
                description: nil,
                dueDate: nil,
                dueDateTime: nil
            )
            AppIntentHaptics.notify()
            Current.Log.info("Successfully added todo item to list \(listId)")
        } catch {
            AppIntentHaptics.notify(.error)
            Current.Log.error("Failed to add todo item to list \(listId): \(error)")
        }
    }
}
