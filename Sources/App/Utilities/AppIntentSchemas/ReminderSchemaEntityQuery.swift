import AppIntents
import Foundation
import Shared

/// Todo items are not cached locally, so this reads them from the server a list at a time, the same
/// way the todo widget does.
@available(iOS 27.0, *)
struct ReminderSchemaEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ReminderSchemaEntity] {
        let wanted = Set(identifiers)
        return await items().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [ReminderSchemaEntity] {
        await items().filter { $0.title.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [ReminderSchemaEntity] {
        await items()
    }

    private func items() async -> [ReminderSchemaEntity] {
        var results: [ReminderSchemaEntity] = []
        for list in await (try? ReminderListSchemaEntityQuery().suggestedEntities()) ?? [] {
            guard let server = Current.servers.server(for: .init(rawValue: list.serverId)),
                  let api = Current.api(for: server) else {
                continue
            }
            do {
                let items = try await api.todoListItems(listId: list.entityId)
                results.append(contentsOf: items.map { ReminderSchemaEntity(item: $0, list: list) })
            } catch {
                Current.Log.error("Failed to read todo items for \(list.entityId): \(error.localizedDescription)")
            }
        }
        return results
    }
}
