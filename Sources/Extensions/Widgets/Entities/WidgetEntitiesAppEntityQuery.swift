import AppIntents
import Foundation
import Shared

/// Offers the entities of the server picked in the widget configuration.
///
/// The picker only lists the chosen server's entities, sorted by name with the ones that have no
/// area or device to show last, so a household with several servers is never offered a mix. Saved
/// picks still resolve from any server, so a configuration made before a server was renamed or
/// reordered keeps its tiles.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetEntitiesAppEntityQuery: EntityQuery, EntityStringQuery {
    @IntentParameterDependency<WidgetEntitiesAppIntent>(\.$server)
    var config

    /// Resolves in the order the identifiers were saved, which is the order the user picked the
    /// entities in and the order the widget draws them.
    func entities(for identifiers: [WidgetEntitiesAppEntity.ID]) async throws -> [WidgetEntitiesAppEntity] {
        let byId = Dictionary(
            entitiesPerServer().flatMap(\.1).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return identifiers.compactMap { byId[$0] }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<WidgetEntitiesAppEntity> {
        collection(for: entitiesPerServer(matching: string))
    }

    func suggestedEntities() async throws -> IntentItemCollection<WidgetEntitiesAppEntity> {
        collection(for: entitiesPerServer())
    }

    /// Scoped to the configured server as a flat list. Without one — the picker opened before the
    /// server parameter resolved — every server's entities are offered, grouped under its name.
    private func collection(
        for entitiesPerServer: [(Server, [WidgetEntitiesAppEntity])]
    ) -> IntentItemCollection<WidgetEntitiesAppEntity> {
        if let server = config?.server {
            let items = entitiesPerServer.first { $0.0.identifier.rawValue == server.id }?.1 ?? []
            return .init(items: items)
        }
        return .init(sections: entitiesPerServer.map { server, items in
            .init(.init(stringLiteral: server.info.name), items: items)
        })
    }

    /// Every server's entities as the picker offers them: sorted by name, or ranked by relevance
    /// when there is a search string. Either way the entities with nothing to say about where they
    /// are — no area, no device — come after the ones that have a context line worth reading.
    func entitiesPerServer(matching string: String? = nil) -> [(Server, [WidgetEntitiesAppEntity])] {
        let entities = ControlEntityProvider(domains: []).getEntities(matching: string)
        let isSearching = !(string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return entities.map { server, values in
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
            var items = values.map { entity in
                WidgetEntitiesAppEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: deviceMap[entity.entityId]?.name,
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name
                )
            }
            // A search comes back ranked by relevance, which is worth more than alphabetical order.
            if !isSearching {
                items.sort { $0.displayString.localizedCaseInsensitiveCompare($1.displayString) == .orderedAscending }
            }
            // A stable split, so whichever order the two groups were in survives within each.
            items = items.filter(\.hasContext) + items.filter { !$0.hasContext }
            return (server, items)
        }
    }
}
