import AppIntents
import Foundation
import PromiseKit
import SFSafeSymbols
import Shared

@available(macOS 13.0, *)
struct IntentSceneEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Scene")

    static let defaultQuery = IntentSceneAppEntityQuery()

    var id: String
    @Property(title: .init("app_intents.entity.property.entity_id", defaultValue: "Entity ID"))
    var entityId: String
    var serverId: String
    @Property(title: .init("app_intents.entity.property.server", defaultValue: "Server"))
    var serverName: String
    @Property(title: .init("app_intents.entity.property.area", defaultValue: "Area"))
    var areaName: String?
    @Property(title: .init("app_intents.entity.property.device", defaultValue: "Device"))
    var deviceName: String?
    @Property(title: .init("app_intents.entity.property.floor", defaultValue: "Floor"))
    var floorName: String?
    @Property(title: .init("app_intents.entity.property.name", defaultValue: "Name"))
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
        self.serverId = serverId
        self.iconName = iconName
        self.entityId = entityId
        self.serverName = serverName
        self.areaName = areaName
        self.deviceName = deviceName
        self.floorName = floorName
        self.displayString = displayString
    }
}

@available(macOS 13.0, *)
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
