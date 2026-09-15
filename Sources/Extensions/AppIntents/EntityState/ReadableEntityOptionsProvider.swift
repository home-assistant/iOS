import AppIntents
import Foundation
import SFSafeSymbols
import Shared

/// What "get entity state" offers: everything worth asking a question about.
///
/// Wider than the on/off list, because reading a state is safe where changing it is not, and because
/// "what is on" should not quietly skip a running vacuum or an unlocked door. Narrower than the
/// shared query behind widgets and Spotlight, which legitimately offers diagnostics, configuration
/// entities and things in no room — a spoken question should not.
@available(macOS 13.0, watchOS 9.4, *)
struct ReadableEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        .init(sections: entitiesPerServer().map { server, items in
            .init(.init(stringLiteral: server.info.name), items: items)
        })
    }

    private func entitiesPerServer() -> [(Server, [HAAppEntityAppIntentEntity])] {
        // A picker groups by server, but a row stands alone in Siri's disambiguation, where two homes
        // can share a name — so the server leads the context line once there is more than one.
        let namesTheServer = Current.servers.all.count > 1
        // Every domain: narrowing to the ones a command can *change* would drop the sensors people
        // most often ask for. What this leaves out is decided by `userFacingInAreas` below.
        let byServer = ControlEntityProvider(domains: []).getEntitiesExposedToSiri()
        // Siri offers them in the order they arrive, so the likeliest server leads.
        let rank = Dictionary(
            uniqueKeysWithValues: ServerPriority.ordered(byServer.map(\.0)).enumerated()
                .map { ($0.element.identifier, $0.offset) }
        )
        return byServer.sorted { rank[$0.0.identifier] ?? .max < rank[$1.0.identifier] ?? .max }
            .map { server, allValues in
                let values = allValues.userFacingInAreas(serverId: server.identifier.rawValue)
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
