import AppIntents
import Foundation
import SFSafeSymbols
import Shared

/// What "turn on, off or toggle" offers: the entities a spoken command should switch, and the rooms
/// it should switch all at once.
///
/// A provider rather than an entity type of its own. The thing being named is one Home Assistant
/// entity whichever command asks for it, so `HAAppEntityAppIntentEntity` is the whole model; what
/// differs between commands is only which of them are worth offering, which is what this narrows.
/// Covers are the exception that stayed a type — see `OpenableEntityAppEntity`.
@available(macOS 13.0, watchOS 9.4, *)
struct ControllableEntityOptionsProvider: DynamicOptionsProvider {
    typealias Section = IntentItemSection<HAAppEntityAppIntentEntity>

    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        .init(sections: entitiesPerServer().flatMap { sections(for: $0.0, entities: $0.1) })
    }

    private func sections(for server: Server, entities: [HAAppEntityAppIntentEntity]) -> [Section] {
        var sections: [Section] = []
        if !entities.isEmpty {
            sections.append(.init(.init(stringLiteral: server.info.name), items: entities))
        }
        // A whole area, offered next to the individual entities so "turn on the kitchen lights"
        // reaches every light in the room without needing a shortcut of its own.
        let areas = HAAppEntityAppIntentEntity.areaTargets(
            for: server,
            matching: nil,
            domains: Domain.voiceSwitchOffered
        )
        if !areas.isEmpty {
            sections.append(.init(
                .init(stringLiteral: L10n.AppIntents.AreaTarget.areasSection(server.info.name)),
                items: areas
            ))
        }
        return sections
    }

    /// Covers are left out: they are offered by the open and close command, where the wording matches
    /// the service. Resolution stays wider than this on purpose — an id that was valid once should
    /// keep resolving, whether it came from a shortcut, an automation or a donation — and that is the
    /// shared query's job, not this one's.
    private func entitiesPerServer() -> [(Server, [HAAppEntityAppIntentEntity])] {
        // A picker groups by server, but a row stands alone in Siri's disambiguation, where two homes
        // can share a name — so the server leads the context line once there is more than one.
        let namesTheServer = Current.servers.all.count > 1
        let byServer = ControlEntityProvider(domains: Domain.voiceSwitchOffered).getEntitiesExposedToSiri()
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
