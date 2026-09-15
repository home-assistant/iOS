import AppIntents
import Foundation
import SFSafeSymbols
import Shared

/// What "show" offers: everything worth opening the details of by name.
///
/// Wider than the on/off list, because opening something is safe where changing it is not, and
/// because the sensors are what people most often name. Narrower than the shared query behind widgets
/// and the Spotlight index, which legitimately carries diagnostics, configuration entities and things
/// in no room — a spoken request should not offer those.
///
/// A provider rather than a type of its own, because "show" opens the entity the Spotlight index
/// publishes and so has to keep taking `HAAppEntityAppIntentEntity`. "Get entity state" asks for the
/// same entities but through `ReadableEntityAppEntity`, so that a tapped search result has only one
/// intent to reach for; both narrow through `voiceReadableEntities` so the two lists cannot drift.
@available(macOS 13.0, watchOS 9.4, *)
struct ReadableEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        .init(sections: entitiesPerServer().map { server, items in
            .init(.init(stringLiteral: server.info.name), items: items)
        })
    }

    /// The entities a spoken request may name, per server, likeliest server first: the voice-readable
    /// domains, and only the user-facing ones that sit in a room.
    static func voiceReadableEntities(matching string: String? = nil) -> [(Server, [HAAppEntity])] {
        let byServer = ControlEntityProvider(domains: Domain.voiceReadable)
            .getEntitiesExposedToSiri(matching: string)
        // Siri offers them in the order they arrive, so the likeliest server leads.
        let rank = Dictionary(
            uniqueKeysWithValues: ServerPriority.ordered(byServer.map(\.0)).enumerated()
                .map { ($0.element.identifier, $0.offset) }
        )
        return byServer.sorted { rank[$0.0.identifier] ?? .max < rank[$1.0.identifier] ?? .max }
            .map { server, allValues in
                (server, allValues.userFacingInAreas(serverId: server.identifier.rawValue))
            }
    }

    private func entitiesPerServer() -> [(Server, [HAAppEntityAppIntentEntity])] {
        // A picker groups by server, but a row stands alone in Siri's disambiguation, where two homes
        // can share a name — so the server leads the context line once there is more than one.
        let namesTheServer = Current.servers.all.count > 1
        return Self.voiceReadableEntities()
            .map { server, values in
                let deviceMap = values.devicesMap(for: server.identifier.rawValue)
                let areasMap = values.areasMap(for: server.identifier.rawValue)
                let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
                return (server, values.map { entity in
                    HAAppEntityAppIntentEntity(
                        id: entity.id,
                        entityId: entity.entityId,
                        serverId: entity.serverId,
                        serverName: server.info.name,
                        areaName: areasMap[entity.entityId]?.name,
                        deviceName: deviceMap[entity.entityId]?.name,
                        floorName: floorMap[entity.entityId],
                        displayString: entity.name,
                        iconName: entity.icon ?? SFSymbol.powerCircleFill.rawValue,
                        includesServerContext: namesTheServer
                    )
                })
            }
    }
}
