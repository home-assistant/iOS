import AppIntents
import Foundation
import PromiseKit
import SFSafeSymbols
import Shared

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentSceneEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Scene")

    static let defaultQuery = IntentSceneAppEntityQuery()

    var id: String
    var entityId: String
    var serverId: String
    var serverName: String
    var areaName: String?
    var deviceName: String?
    var floorName: String?
    var displayString: String
    var iconName: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: contextSubtitle.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        serverName: String,
        areaName: String? = nil,
        deviceName: String? = nil,
        floorName: String? = nil,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.serverName = serverName
        self.areaName = areaName
        self.deviceName = deviceName
        self.floorName = floorName
        self.displayString = displayString
        self.iconName = iconName
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentSceneAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentSceneEntity] {
        getSceneEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentSceneEntity> {
        .init(sections: getSceneEntities(matching: string).map { (key: Server, value: [IntentSceneEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter { $0.displayString.lowercased().contains(string.lowercased()) }
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentSceneEntity> {
        .init(sections: getSceneEntities().map { (key: Server, value: [IntentSceneEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getSceneEntities(matching string: String? = nil) -> [(Server, [IntentSceneEntity])] {
        var sceneEntities: [(Server, [IntentSceneEntity])] = []
        let entities = ControlEntityProvider(domains: [.scene]).getEntities(matching: string)

        for (server, values) in entities {
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
            sceneEntities.append((server, values.map({ entity in
                IntentSceneEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: deviceMap[entity.entityId]?.name,
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.moonStarsCircleFill.rawValue
                )
            })))
        }

        return sceneEntities
    }
}
