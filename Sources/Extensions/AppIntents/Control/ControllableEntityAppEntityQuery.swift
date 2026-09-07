import AppIntents
import Foundation
import SFSafeSymbols
import Shared

@available(macOS 13.0, watchOS 9.4, *)
struct ControllableEntityAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ControllableEntityAppEntity] {
        let byServer = entities(domains: Domain.voiceControllable)
        let resolved = byServer.flatMap(\.1).filter { identifiers.contains($0.id) }
        // An area id resolves through the same builder the picker used, so a saved shortcut keeps
        // working whether it stored one entity or a whole room of them.
        let areas = byServer.flatMap { server, _ in
            areaRows(for: server, domains: Domain.voiceControllable, matching: nil)
        }
        .filter { identifiers.contains($0.id) }
        return resolved + areas
    }

    func entities(matching string: String) async throws -> IntentItemCollection<ControllableEntityAppEntity> {
        collection(for: entities(matching: string), matching: string)
    }

    func suggestedEntities() async throws -> IntentItemCollection<ControllableEntityAppEntity> {
        collection(for: entities())
    }

    private func collection(
        for entitiesPerServer: [(Server, [ControllableEntityAppEntity])],
        matching string: String? = nil
    ) -> IntentItemCollection<ControllableEntityAppEntity> {
        .init(sections: entitiesPerServer.flatMap { server, items -> [IntentItemSection<ControllableEntityAppEntity>] in
            var sections: [IntentItemSection<ControllableEntityAppEntity>] = []
            if !items.isEmpty {
                sections.append(.init(.init(stringLiteral: server.info.name), items: items))
            }
            let areas = areaRows(for: server, domains: Domain.voiceSwitchOffered, matching: string)
            if !areas.isEmpty {
                sections.append(.init(
                    .init(stringLiteral: L10n.AppIntents.AreaTarget.areasSection(server.info.name)),
                    items: areas
                ))
            }
            return sections
        })
    }

    /// A whole area of one domain, offered next to the individual entities so "turn on the kitchen
    /// lights" reaches every light in the room without needing a shortcut of its own.
    private func areaRows(
        for server: Server,
        domains: [Domain],
        matching string: String?
    ) -> [ControllableEntityAppEntity] {
        AreaTargetProvider.targets(for: server, domains: domains, matching: string)
            .map {
                ControllableEntityAppEntity(
                    areaTarget: $0,
                    serverId: server.identifier.rawValue,
                    serverName: server.info.name
                )
            }
    }

    private func entities(
        matching string: String? = nil,
        domains: [Domain] = Domain.voiceSwitchOffered
    ) -> [(Server, [ControllableEntityAppEntity])] {
        // Suggestions leave covers out: they are offered by the open and close command, where the
        // wording matches the service. Resolution stays wider than this on purpose — an id that was
        // valid once should keep resolving, whether it came from a shortcut, an automation or a
        // donation.
        let byServer = ControlEntityProvider(domains: domains).getEntitiesExposedToSiri(matching: string)
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
