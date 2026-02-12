import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
import Shared

@available(iOS 17.0, *)
struct TodoListAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "To-do List")

    static let defaultQuery = TodoListAppEntityQuery()

    var id: String
    var entityId: String
    var serverId: String
    var displayString: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        displayString: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.displayString = displayString
    }
}

@available(iOS 17.0, *)
struct TodoListAppEntityQuery: EntityQuery, EntityStringQuery {
    @IntentParameterDependency<WidgetTodoListAppIntent>(\.$server)
    var serverDependency

    func entities(for identifiers: [String]) async throws -> [TodoListAppEntity] {
        await getTodoListEntities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<TodoListAppEntity> {
        let lists = await getTodoListEntities(matching: string)
        return .init(items: lists)
    }

    func suggestedEntities() async throws -> IntentItemCollection<TodoListAppEntity> {
        let lists = await getTodoListEntities()
        return .init(items: lists)
    }

    private func getTodoListEntities(matching string: String? = nil) async -> [TodoListAppEntity] {
        guard let serverId = serverDependency?.server?.id,
              let server = Current.servers.server(for: .init(rawValue: serverId)),
              let api = Current.api(for: server) else {
            return []
        }

        // Fetch todo entities from the API
        do {
            let states = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HAEntity], Error>) in
                api.connection.send(.init(type: .rest(.get, "states"))).promise.done { data in
                    guard case let .array(statesArray) = data else {
                        continuation.resume(returning: [])
                        return
                    }
                    let entities = statesArray.compactMap { try? HAEntity(data: $0) }
                    continuation.resume(returning: entities)
                }.catch { error in
                    continuation.resume(throwing: error)
                }
            }

            let todoEntities = states
                .filter { $0.domain == "todo" }
                .filter { entity in
                    if let string, !string.isEmpty {
                        return entity.attributes.friendlyName?.localizedCaseInsensitiveContains(string) ?? false
                    }
                    return true
                }
                .map { entity in
                    TodoListAppEntity(
                        id: "\(serverId)-\(entity.entityId)",
                        entityId: entity.entityId,
                        serverId: serverId,
                        displayString: entity.attributes.friendlyName ?? entity.entityId
                    )
                }

            return todoEntities
        } catch {
            Current.Log.error("Failed to fetch todo entities: \(error)")
            return []
        }
    }
}
