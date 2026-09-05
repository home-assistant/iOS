import AppIntents
import Foundation
import SFSafeSymbols
import Shared

@available(macOS 13.0, watchOS 9.4, *)
struct ControllableEntityAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ControllableEntityAppEntity] {
        entities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<ControllableEntityAppEntity> {
        collection(for: entities(matching: string))
    }

    func suggestedEntities() async throws -> IntentItemCollection<ControllableEntityAppEntity> {
        collection(for: entities())
    }

    private func collection(
        for entitiesPerServer: [(Server, [ControllableEntityAppEntity])]
    ) -> IntentItemCollection<ControllableEntityAppEntity> {
        .init(sections: entitiesPerServer.map { server, items in
            .init(.init(stringLiteral: server.info.name), items: items)
        })
    }

    private func entities(matching string: String? = nil) -> [(Server, [ControllableEntityAppEntity])] {
        ControlEntityProvider(domains: Domain.voiceControllable).getEntities(matching: string).map { server, values in
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
            return (server, values.map { entity in
                ControllableEntityAppEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: deviceMap[entity.entityId]?.name,
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.powerCircleFill.rawValue
                )
            })
        }
    }
}
