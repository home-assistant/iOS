import AppIntents
import GRDB
import PromiseKit
import RealmSwift
import Shared
import WidgetKit

struct WidgetTodoListEntry: TimelineEntry {
    let date: Date
    let listTitle: String
    let items: [String]
    let family: WidgetFamily
}

enum WidgetTodoListAppIntentTimelineProviderError: Error {
    case failedToFetchItems
}

@available(iOS 17, *)
struct WidgetTodoListAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetTodoListEntry
    typealias Intent = WidgetTodoListAppIntent

    static var expiration: Measurement<UnitDuration> {
        .init(value: 15, unit: .minutes)
    }

    func snapshot(for configuration: WidgetTodoListAppIntent, in context: Context) async -> WidgetTodoListEntry {
        .init(date: Date(), listTitle: "List", items: [], family: context.family)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let listId = configuration.list ?? "todo.supermercado"

        do {
            let rawItems = try await withCheckedThrowingContinuation { continuation in
                Current.api(for: Current.servers.all.first!)?.connection.send(.getItemFromTodoList(listId: listId)).promise.pipe { result in
                    switch result {
                    case .fulfilled(let todoListRawResponse):
                        continuation.resume(returning: todoListRawResponse.serviceResponse.first?.value.items ?? [])
                    case .rejected(let error):
                        Current.Log.error("Failed to fetch todo items for list \(listId): \(error)")
                        continuation.resume(throwing: WidgetTodoListAppIntentTimelineProviderError.failedToFetchItems)
                    }
                }
            }
            let items = rawItems.map(\.summary).prefix(
                WidgetFamilySizes.todoListSize(for: context.family)
            )
            return Timeline(entries: [.init(date: Date(), listTitle: listId, items: Array(items), family: context.family)], policy: .atEnd)
        } catch {
            Current.Log.error("Error fetching todo items: \(error)")
            return .init(entries: [], policy: .atEnd)
        }
    }

    func placeholder(in context: Context) -> Entry {
        .init(date: Date(), listTitle: "List", items: [], family: context.family)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetTodoListAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "To do list"

    static var isDiscoverable: Bool = false

    @Parameter(
        title: "To do list"
    )
    var list: String?

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: true)
    }
}
