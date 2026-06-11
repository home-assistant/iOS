import AppIntents
import GRDB
import Shared
import WidgetKit

struct WidgetTodoListEntry: TimelineEntry {
    let date: Date
    let serverId: String
    let listId: String
    let listTitle: String
    let items: [TodoListItem]
    let family: WidgetFamily
}

enum WidgetTodoListAppIntentTimelineProviderError: Error {
    case failedToFetchItems
    case noServerAvailable
    case noListSelected
}

@available(iOS 17, *)
struct WidgetTodoListAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetTodoListEntry
    typealias Intent = WidgetTodoListAppIntent

    private struct SelectedList {
        let serverId: String
        let entityId: String
        let displayString: String
    }

    private func selectedList(for configuration: Intent) -> SelectedList? {
        if let list = configuration.list {
            return SelectedList(
                serverId: list.serverId,
                entityId: list.entityId,
                displayString: list.displayString
            )
        }

        let preferredServerId = configuration.server?.id
        let entities = ControlEntityProvider(domains: [.todo]).getEntities()

        if let preferredServerId {
            for (server, values) in entities where server.identifier.rawValue == preferredServerId {
                if let entity = values.first {
                    return SelectedList(
                        serverId: entity.serverId,
                        entityId: entity.entityId,
                        displayString: entity.name
                    )
                }
            }
        }

        for (_, values) in entities {
            if let entity = values.first {
                return SelectedList(
                    serverId: entity.serverId,
                    entityId: entity.entityId,
                    displayString: entity.name
                )
            }
        }

        return nil
    }

    func snapshot(for configuration: WidgetTodoListAppIntent, in context: Context) async -> WidgetTodoListEntry {
        .init(
            date: Date(),
            serverId: "",
            listId: "",
            listTitle: "",
            items: [],
            family: context.family
        )
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        guard let selectedList = selectedList(for: configuration) else {
            return Timeline(
                entries: [.init(
                    date: Date(),
                    serverId: "",
                    listId: "",
                    listTitle: "",
                    items: [],
                    family: context.family
                )],
                policy: .atEnd
            )
        }

        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == selectedList.serverId }),
              let api = Current.api(for: server) else {
            Current.Log.error("No server available for todo list widget")
            return Timeline(
                entries: [.init(
                    date: Date(),
                    serverId: selectedList.serverId,
                    listId: selectedList.entityId,
                    listTitle: selectedList.displayString,
                    items: [],
                    family: context.family
                )],
                policy: .atEnd
            )
        }

        do {
            let rawItems = try await withCheckedThrowingContinuation { continuation in
                api.connection.send(.getItemFromTodoList(listId: selectedList.entityId)).promise.pipe { result in
                    switch result {
                    case let .fulfilled(todoListRawResponse):
                        continuation.resume(returning: todoListRawResponse.serviceResponse.first?.value.items ?? [])
                    case let .rejected(error):
                        Current.Log.error("Failed to fetch todo items for list \(selectedList.entityId): \(error)")
                        continuation.resume(throwing: WidgetTodoListAppIntentTimelineProviderError.failedToFetchItems)
                    }
                }
            }

            // Filter only items that need action and limit based on widget size
            let activeItems = rawItems
                .filter { $0.status == "needs_action" }
                .prefix(WidgetFamilySizes.todoListSize(for: context.family))

            return Timeline(
                entries: [.init(
                    date: Date(),
                    serverId: selectedList.serverId,
                    listId: selectedList.entityId,
                    listTitle: selectedList.displayString,
                    items: Array(activeItems),
                    family: context.family
                )],
                policy: .atEnd
            )
        } catch {
            Current.Log.error("Error fetching todo items: \(error)")
            return Timeline(
                entries: [.init(
                    date: Date(),
                    serverId: selectedList.serverId,
                    listId: selectedList.entityId,
                    listTitle: selectedList.displayString,
                    items: [],
                    family: context.family
                )],
                policy: .atEnd
            )
        }
    }

    func placeholder(in context: Context) -> Entry {
        .init(
            date: Date(),
            serverId: "",
            listId: "",
            listTitle: "Shopping List",
            items: [
                TodoListItem(summary: "Milk", uid: "1", status: "needs_action", description: ""),
                TodoListItem(summary: "Bread", uid: "2", status: "needs_action", description: ""),
                TodoListItem(summary: "Eggs", uid: "3", status: "needs_action", description: ""),
            ],
            family: context.family
        )
    }
}
