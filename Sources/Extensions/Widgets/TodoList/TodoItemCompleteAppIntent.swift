import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 17.0, *)
struct TodoItemCompleteAppIntent: AppIntent {
    static var title: LocalizedStringResource = "widgets.todo_list.complete_item_title"
    static var isDiscoverable: Bool = false

    @Parameter(title: "widgets.todo_list.parameter.server_id")
    var serverId: String

    @Parameter(title: "widgets.todo_list.parameter.list_id")
    var listId: String

    @Parameter(title: "widgets.todo_list.parameter.item_id")
    var itemId: String

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.haptic_confirmation.title",
            defaultValue: "Haptic confirmation"
        ),
        default: true
    )
    var hapticConfirmation: Bool

    init() {
        self.serverId = ""
        self.listId = ""
        self.itemId = ""
        self.hapticConfirmation = true
    }

    init(serverId: String, listId: String, itemId: String) {
        self.serverId = serverId
        self.listId = listId
        self.itemId = itemId
        self.hapticConfirmation = true
    }

    func perform() async throws -> some IntentResult {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
              let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No server found for completing todo item, serverId: \(serverId)")
            return .result()
        }

        if hapticConfirmation {
            AppIntentHaptics.notify()
        }

        await withCheckedContinuation { continuation in
            connection.send(.completeTodoItem(listId: listId, itemId: itemId)).promise.pipe { result in
                switch result {
                case .fulfilled:
                    Current.Log.info("Successfully completed todo item \(itemId) in list \(listId)")
                    continuation.resume()
                case let .rejected(error):
                    Current.Log.error("Failed to complete todo item \(itemId) in list \(listId): \(error)")
                    continuation.resume()
                }
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.todoList.rawValue)
        return .result()
    }
}
