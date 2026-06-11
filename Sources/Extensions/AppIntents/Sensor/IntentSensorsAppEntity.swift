import AppIntents
import Foundation
import SFSafeSymbols
import Shared

@available(iOS 17.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct IntentSensorsAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sensor")

    static let defaultQuery = IntentSensorsAppEntityQuery()

    // UniqueID: serverId-entityId
    var id: String
    var entityId: String
    var serverId: String
    var displayString: String
    var icon: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        displayString: String,
        icon: String?
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.displayString = displayString
        self.icon = icon
    }
}

@available(iOS 17.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct IntentSensorsAppEntityQuery: EntityQuery {
    func entities(for identifiers: [IntentSensorsAppEntity.ID]) async throws -> [IntentSensorsAppEntity] {
        getSensorEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentSensorsAppEntity> {
        let sensorsPerServer = getSensorEntities()

        return .init(sections: sensorsPerServer.map { (key: Server, value: [IntentSensorsAppEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    func defaultResult() async -> IntentSensorsAppEntity? {
        getSensorEntities().flatMap(\.1).first
    }

    private func getSensorEntities(matching string: String? = nil) -> [(Server, [IntentSensorsAppEntity])] {
        var sensorEntities: [(Server, [IntentSensorsAppEntity])] = []
        let entities = ControlEntityProvider(domains: WidgetSensorsConfig.domains).getEntities(matching: string)

        for (server, values) in entities {
            sensorEntities.append((server, values.map({ entity in
                IntentSensorsAppEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    displayString: entity.name,
                    icon: entity.icon
                )
            })))
        }

        return sensorEntities
    }
}
