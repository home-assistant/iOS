import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
import Shared

@available(iOS 17.0, *)
struct TodoListAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widgets.todo_list.title")

    static let defaultQuery = TodoListAppEntityQuery()

    // UniqueID: serverId-entityId
    var id: String
    @Property(title: .init("app_intents.entity.property.entity_id", defaultValue: "Entity ID"))
    var entityId: String
    var serverId: String
    @Property(title: .init("app_intents.entity.property.name", defaultValue: "Name"))
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
        self.serverId = serverId
        self.iconName = iconName
        self.entityId = entityId
        self.displayString = displayString
    }
}

@available(iOS 17.0, *)
struct TodoListAppEntityQuery: EntityQuery, EntityStringQuery {
    @IntentParameterDependency<WidgetTodoListAppIntent>(\.$server)
    var requirement

    func entities(for identifiers: [String]) async throws -> [TodoListAppEntity] {
        getTodoListEntities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<TodoListAppEntity> {
        let lists = getTodoListEntities(matching: string)
        return .init(items: lists)
    }

    func suggestedEntities() async throws -> IntentItemCollection<TodoListAppEntity> {
        let lists = getTodoListEntities()
        return .init(items: lists)
    }

    private func getTodoListEntities(matching string: String? = nil) -> [TodoListAppEntity] {
        var todoEntities: [TodoListAppEntity] = []

        // Get the selected server from the dependency
        guard let serverId = requirement?.server.id else {
            return []
        }

        let entities = ControlEntityProvider(domains: [.todo]).getEntities(matching: string)

        for (entityServer, values) in entities {
            // Only include entities from the selected server
            guard entityServer.identifier.rawValue == serverId else { continue }

            todoEntities.append(contentsOf: values.map { entity in
                TodoListAppEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.checklistChecked.rawValue
                )
            })
        }

        return todoEntities
    }
}
