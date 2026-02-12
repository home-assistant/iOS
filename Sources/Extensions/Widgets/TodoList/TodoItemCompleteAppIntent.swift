import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 17.0, *)
struct TodoItemCompleteAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete To-do Item"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Server ID")
    var serverId: String

    @Parameter(title: "List ID")
    var listId: String

    @Parameter(title: "Item ID")
    var itemId: String

    init() {
        self.serverId = ""
        self.listId = ""
        self.itemId = ""
    }

    init(serverId: String, listId: String, itemId: String) {
        self.serverId = serverId
        self.listId = listId
        self.itemId = itemId
    }

    func perform() async throws -> some IntentResult {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
              let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No server found for completing todo item, serverId: \(serverId)")
            return .result()
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
