import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
import Shared

@available(iOS 17.0, *)
struct TodoListAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "To-do List")

    static let defaultQuery = TodoListAppEntityQuery()

    // UniqueID: serverId-entityId
    var id: String
    var entityId: String
    var serverId: String
    var displayString: String
    var iconName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.displayString = displayString
        self.iconName = iconName
    }
}

@available(iOS 17.0, *)
struct TodoListAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [TodoListAppEntity] {
        getTodoListEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<TodoListAppEntity> {
        let listsPerServer = getTodoListEntities(matching: string)

        return .init(sections: listsPerServer.map { (key: Server, value: [TodoListAppEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<TodoListAppEntity> {
        let listsPerServer = getTodoListEntities()

        return .init(sections: listsPerServer.map { (key: Server, value: [TodoListAppEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getTodoListEntities(matching string: String? = nil) -> [(Server, [TodoListAppEntity])] {
        var todoEntities: [(Server, [TodoListAppEntity])] = []
        let entities = ControlEntityProvider(domains: [.todo]).getEntities(matching: string)

        for (server, values) in entities {
            todoEntities.append((server, values.map { entity in
                TodoListAppEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.checklistChecked.rawValue
                )
            }))
        }

        return todoEntities
    }
}
