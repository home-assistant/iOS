import AppIntents
import SFSafeSymbols
import Shared

@available(macOS 13.0, watchOS 9.4, *)
struct IntentScriptAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentScriptEntity] {
        getScriptEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentScriptEntity> {
        let scriptsPerServer = getScriptEntities()

        return .init(sections: scriptsPerServer.map { (key: Server, value: [IntentScriptEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter { $0.displayString.lowercased().contains(string.lowercased()) }
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentScriptEntity> {
        let scriptsPerServer = getScriptEntities()

        return .init(sections: scriptsPerServer.map { (key: Server, value: [IntentScriptEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    /// Scripts are read from the local entity mirror, which both iOS and watchOS keep in GRDB, so
    /// this needs no server round trip on either platform.
    private func getScriptEntities(matching string: String? = nil) -> [(Server, [IntentScriptEntity])] {
        var scriptEntities: [(Server, [IntentScriptEntity])] = []
        let entities = ControlEntityProvider(domains: [.script]).getEntities(matching: string)

        for (server, values) in entities {
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
            scriptEntities.append((server, values.map({ entity in
                IntentScriptEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: deviceMap[entity.entityId]?.name,
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.applescriptFill.rawValue
                )
            })))
        }

        return scriptEntities
    }
}
