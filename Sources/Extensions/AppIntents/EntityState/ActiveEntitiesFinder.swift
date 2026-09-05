import AppIntents
import Foundation
import HAKit
import SFSafeSymbols
import Shared

/// Finds the entities a person would call "on" right now, and words the answer.
@available(macOS 13.0, *)
enum ActiveEntitiesFinder {
    /// One states call per server, joined against the local mirror so each result keeps its name and area.
    static func active(matching filter: ActiveEntitiesFilterAppEnum) async throws -> [HAEntityStateAppEntity] {
        let domains = filter.domains
        let known = ControlEntityProvider(domains: domains).getEntities()
        guard !Current.servers.all.isEmpty else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        var results: [HAEntityStateAppEntity] = []
        for (server, mirrored) in known {
            let states = try await AppIntentServerAPI.entities(server: server, domains: domains)
            let activeIds = Set(
                states
                    .filter { EntityStateActive.isActive(domain: $0.domain, state: $0.state) }
                    .map(\.entityId)
            )
            let statesById = Dictionary(states.map { ($0.entityId, $0) }, uniquingKeysWith: { first, _ in first })
            let areasMap = mirrored.areasMap(for: server.identifier.rawValue)
            let deviceMap = mirrored.devicesMap(for: server.identifier.rawValue)
            let floorMap = mirrored.floorNamesMap(for: server.identifier.rawValue)

            for entity in mirrored where activeIds.contains(entity.entityId) {
                guard let state = statesById[entity.entityId] else { continue }
                let described = HAAppEntityAppIntentEntity(
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
                results.append(HAEntityStateAppEntity(entity: described, state: state))
            }
        }
        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The spoken answer: the names when there are any, and the plural noun when there are none.
    static func dialog(for entities: [HAEntityStateAppEntity], filter: ActiveEntitiesFilterAppEnum) -> String {
        let kind = filter.localizedPluralName
        guard !entities.isEmpty else {
            return filter.readsAsOpen
                ? L10n.AppIntents.ActiveEntities.Dialog.noneOpen(kind)
                : L10n.AppIntents.ActiveEntities.Dialog.noneOn(kind)
        }
        let names = ListFormatter.localizedString(byJoining: entities.map(\.name))
        return filter.readsAsOpen
            ? L10n.AppIntents.ActiveEntities.Dialog.someOpen(kind, names)
            : L10n.AppIntents.ActiveEntities.Dialog.someOn(kind, names)
    }
}

@available(macOS 13.0, *)
extension ActiveEntitiesFilterAppEnum {
    /// The same plural noun the phrases use, read back out of the display representations.
    var localizedPluralName: String {
        guard let representation = Self.caseDisplayRepresentations[self] else { return rawValue }
        return String(localized: representation.title)
    }
}
