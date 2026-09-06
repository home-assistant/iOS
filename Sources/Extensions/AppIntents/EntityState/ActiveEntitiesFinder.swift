import AppIntents
import Foundation
import HAKit
import SFSafeSymbols
import Shared

/// Finds the entities a person would call "on" right now, and words the answer.
@available(macOS 13.0, *)
enum ActiveEntitiesFinder {
    /// One states call per server, joined against the local mirror so each result keeps its name and area.
    static func active(
        matching filter: ActiveEntitiesFilterAppEnum,
        state wanted: EntityStateFilterAppEnum = .on
    ) async throws -> [HAEntityStateAppEntity] {
        let domains = filter.domains
        let known = ControlEntityProvider(domains: domains).getEntities()
        guard !Current.servers.all.isEmpty else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        var results: [HAEntityStateAppEntity] = []
        for (server, allMirrored) in known {
            let mirrored = allMirrored.userFacingInAreas(serverId: server.identifier.rawValue)
            let states = try await AppIntentServerAPI.entities(server: server, domains: domains)
            let activeIds = Set(
                states
                    .filter { matches($0, wanted: wanted) }
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
    /// Whether a state belongs on the requested side.
    ///
    /// The inactive side is deliberately not `!isActive`: that predicate also answers false for
    /// `unavailable` and `unknown`, and a light the server can't reach is not a light that is off.
    private static func matches(_ state: HAEntity, wanted: EntityStateFilterAppEnum) -> Bool {
        let isActive = EntityStateActive.isActive(domain: state.domain, state: state.state)
        guard !wanted.wantsActive else { return isActive }
        let raw = state.state.lowercased()
        return !isActive && raw != EntityStateActive.unavailable && raw != EntityStateActive.unknown
    }

    static func dialog(
        for entities: [HAEntityStateAppEntity],
        filter: ActiveEntitiesFilterAppEnum,
        state wanted: EntityStateFilterAppEnum = .on
    ) -> String {
        let kind = filter.localizedPluralName
        // The answer is worded by the kind, not by the word that was spoken, so asking "what lights
        // are open" still reads back as "on".
        let open = filter.readsAsOpen
        guard !entities.isEmpty else {
            switch (wanted.wantsActive, open) {
            case (true, true): return L10n.AppIntents.ActiveEntities.Dialog.noneOpen(kind)
            case (true, false): return L10n.AppIntents.ActiveEntities.Dialog.noneOn(kind)
            case (false, true): return L10n.AppIntents.ActiveEntities.Dialog.noneClosed(kind)
            case (false, false): return L10n.AppIntents.ActiveEntities.Dialog.noneOff(kind)
            }
        }
        let names = ListFormatter.localizedString(byJoining: entities.map(spokenName(for:)))
        switch (wanted.wantsActive, open) {
        case (true, true): return L10n.AppIntents.ActiveEntities.Dialog.someOpen(kind, names)
        case (true, false): return L10n.AppIntents.ActiveEntities.Dialog.someOn(kind, names)
        case (false, true): return L10n.AppIntents.ActiveEntities.Dialog.someClosed(kind, names)
        case (false, false): return L10n.AppIntents.ActiveEntities.Dialog.someOff(kind, names)
        }
    }
}

@available(macOS 13.0, *)
extension ActiveEntitiesFinder {
    /// Names the server only when there is more than one, so a single-server answer stays natural.
    static func spokenName(for entity: HAEntityStateAppEntity) -> String {
        guard Current.servers.all.count > 1, !entity.serverName.isEmpty else {
            return entity.name
        }
        return L10n.AppIntents.ActiveEntities.nameWithServer(entity.name, entity.serverName)
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
