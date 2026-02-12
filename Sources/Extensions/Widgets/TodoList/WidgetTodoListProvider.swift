import AppIntents
import GRDB
import PromiseKit
import RealmSwift
import Shared
import WidgetKit

struct WidgetTodoListEntry: TimelineEntry {
    let date: Date
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

    func snapshot(for configuration: WidgetTodoListAppIntent, in context: Context) async -> WidgetTodoListEntry {
        .init(
            date: Date(),
            listId: "",
            listTitle: "Select a to-do list",
            items: [],
            family: context.family
        )
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        guard let list = configuration.list else {
            return Timeline(
                entries: [.init(
                    date: Date(),
                    listId: "",
                    listTitle: "Select a to-do list",
                    items: [],
                    family: context.family
                )],
                policy: .atEnd
            )
        }

        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == list.serverId }),
              let api = Current.api(for: server) else {
            Current.Log.error("No server available for todo list widget")
            return Timeline(
                entries: [.init(
                    date: Date(),
                    listId: list.entityId,
                    listTitle: list.displayString,
                    items: [],
                    family: context.family
                )],
                policy: .atEnd
            )
        }

        do {
            let rawItems = try await withCheckedThrowingContinuation { continuation in
                api.connection.send(.getItemFromTodoList(listId: list.entityId)).promise.pipe { result in
                    switch result {
                    case let .fulfilled(todoListRawResponse):
                        continuation.resume(returning: todoListRawResponse.serviceResponse.first?.value.items ?? [])
                    case let .rejected(error):
                        Current.Log.error("Failed to fetch todo items for list \(list.entityId): \(error)")
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
                    listId: list.entityId,
                    listTitle: list.displayString,
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
                    listId: list.entityId,
                    listTitle: list.displayString,
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

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetTodoListAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "To-do List"

    static var isDiscoverable: Bool = false

    @Parameter(
        title: "Server"
    )
    var server: IntentServerAppEntity?

    @Parameter(
        title: "List"
    )
    var list: TodoListAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$server
            \.$list
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: true)
    }
}
