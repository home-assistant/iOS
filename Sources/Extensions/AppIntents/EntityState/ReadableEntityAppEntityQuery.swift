import AppIntents
import Foundation
import SFSafeSymbols
import Shared

/// The entities "get entity state" offers, and the wider set it will still resolve.
///
/// What is offered is the shared voice-readable list: wider than the on/off one, because reading a
/// state is safe where changing it is not and the sensors are what people most often ask about, but
/// still filtered by domain and to entities that sit in a room. Resolution stays wider than that, so
/// an id saved in a shortcut keeps working after the entity leaves its area.
@available(macOS 13.0, watchOS 9.4, *)
struct ReadableEntityAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ReadableEntityAppEntity] {
        ControlEntityProvider(domains: [])
            .getEntitiesExposedToSiri()
            .flatMap { server, values in Self.make(values, server: server) }
            .filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<ReadableEntityAppEntity> {
        collection(from: ReadableEntityOptionsProvider.voiceReadableEntities(matching: string))
    }

    func suggestedEntities() async throws -> IntentItemCollection<ReadableEntityAppEntity> {
        collection(from: ReadableEntityOptionsProvider.voiceReadableEntities())
    }

    private func collection(
        from entitiesPerServer: [(Server, [HAAppEntity])]
    ) -> IntentItemCollection<ReadableEntityAppEntity> {
        .init(sections: entitiesPerServer.map { server, values in
            .init(.init(stringLiteral: server.info.name), items: Self.make(values, server: server))
        })
    }

    /// A server's worth of entities, resolving each one's area, device and floor a single time.
    private static func make(_ entities: [HAAppEntity], server: Server) -> [ReadableEntityAppEntity] {
        let serverId = server.identifier.rawValue
        let deviceMap = entities.devicesMap(for: serverId)
        let areasMap = entities.areasMap(for: serverId)
        let floorMap = entities.floorNamesMap(for: serverId)
        return entities.map { entity in
            ReadableEntityAppEntity(
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
        }
    }
}
