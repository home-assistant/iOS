import AppIntents
import Foundation
import SFSafeSymbols
import Shared

/// The entities "turn on, off or toggle" offers, and the wider set it will still resolve.
///
/// What is *offered* follows the same two filters a spoken command has always followed: the domains
/// worth switching by voice, and only the entities that sit in a room — an entity with no area is one
/// nobody asks for by name. Covers are left out, because the open and close command words them the
/// way their service does.
///
/// Resolution is deliberately wider than that: an id that was valid once should keep resolving,
/// whether it came from a shortcut, an automation or a donation, even after the entity leaves its
/// area or its domain stops being offered.
@available(macOS 13.0, watchOS 9.4, *)
struct ControllableEntityAppEntityQuery: EntityQuery, EntityStringQuery {
    typealias Section = IntentItemSection<ControllableEntityAppEntity>

    func entities(for identifiers: [String]) async throws -> [ControllableEntityAppEntity] {
        let byServer = entitiesPerServer(domains: [], inAreasOnly: false)
        let resolved = byServer.flatMap(\.1).filter { identifiers.contains($0.id) }
        // An area id resolves through the same builder the picker used, so a saved shortcut keeps
        // working whether it stored one entity or a whole room of them. Every domain an area can be
        // targeted for is passed, so an id saved while a domain was still offered keeps resolving
        // after it is not.
        //
        // Building them reads the areas back out of the database, so nothing is built until an
        // identifier is left over that could only be a room.
        guard !Set(identifiers).subtracting(resolved.map(\.id)).isEmpty else { return resolved }
        let areas = byServer.flatMap { server, _ in
            areaRows(for: server, domains: AreaTarget.bulkDomains, matching: nil)
        }
        .filter { identifiers.contains($0.id) }
        return resolved + areas
    }

    func entities(matching string: String) async throws -> IntentItemCollection<ControllableEntityAppEntity> {
        collection(for: offeredEntitiesPerServer(matching: string), matching: string)
    }

    func suggestedEntities() async throws -> IntentItemCollection<ControllableEntityAppEntity> {
        collection(for: offeredEntitiesPerServer())
    }

    private func offeredEntitiesPerServer(
        matching string: String? = nil
    ) -> [(Server, [ControllableEntityAppEntity])] {
        entitiesPerServer(domains: Domain.voiceSwitchOffered, inAreasOnly: true, matching: string)
    }

    private func collection(
        for entitiesPerServer: [(Server, [ControllableEntityAppEntity])],
        matching string: String? = nil
    ) -> IntentItemCollection<ControllableEntityAppEntity> {
        .init(sections: entitiesPerServer.flatMap { server, items -> [Section] in
            var sections: [Section] = []
            if !items.isEmpty {
                sections.append(.init(.init(stringLiteral: server.info.name), items: items))
            }
            // A whole area, offered next to the individual entities so "turn on the kitchen lights"
            // reaches every light in the room without needing a shortcut of its own.
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

    /// - Parameters:
    ///   - domains: the domains to offer, or empty to take every one of them.
    ///   - inAreasOnly: whether to keep only the user-facing entities that sit in a room.
    private func entitiesPerServer(
        domains: [Domain],
        inAreasOnly: Bool,
        matching string: String? = nil
    ) -> [(Server, [ControllableEntityAppEntity])] {
        let byServer = ControlEntityProvider(domains: domains).getEntitiesExposedToSiri(matching: string)
        // Siri offers them in the order they arrive, so the likeliest server leads.
        let rank = Dictionary(
            uniqueKeysWithValues: ServerPriority.ordered(byServer.map(\.0)).enumerated()
                .map { ($0.element.identifier, $0.offset) }
        )
        return byServer.sorted { rank[$0.0.identifier] ?? .max < rank[$1.0.identifier] ?? .max }
            .map { server, allValues in
                let serverId = server.identifier.rawValue
                let values = inAreasOnly ? allValues.userFacingInAreas(serverId: serverId) : allValues
                let deviceMap = values.devicesMap(for: serverId)
                let areasMap = values.areasMap(for: serverId)
                let floorMap = values.floorNamesMap(for: serverId)
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
