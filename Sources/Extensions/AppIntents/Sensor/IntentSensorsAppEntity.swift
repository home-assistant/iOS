import AppIntents
import Foundation
import SFSafeSymbols
import Shared

@available(iOS 17.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct IntentSensorsAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sensor")

    static let defaultQuery = IntentDetailsTableAppEntityQuery()

    // UniqueID: serverId-entityId
    var id: String
    var entityId: String
    var serverId: String
    var displayString: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        displayString: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.displayString = displayString
    }

    struct IntentDetailsTableAppEntityQuery: EntityQuery, EntityStringQuery {
        func entities(for identifiers: [IntentSensorsAppEntity.ID]) async throws -> [IntentSensorsAppEntity] {
            getSensorEntities().flatMap(\.value).filter { identifiers.contains($0.id) }
        }

        func entities(matching string: String) async throws -> IntentItemCollection<IntentSensorsAppEntity> {
            let sensorsPerServer = getSensorEntities()

            return .init(sections: sensorsPerServer.map { (key: Server, value: [IntentSensorsAppEntity]) in
                .init(
                    .init(stringLiteral: key.info.name),
                    items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
                )
            })
        }

        func suggestedEntities() async throws -> IntentItemCollection<IntentSensorsAppEntity> {
            let sensorsPerServer = getSensorEntities()

            return .init(sections: sensorsPerServer.map { (key: Server, value: [IntentSensorsAppEntity]) in
                .init(.init(stringLiteral: key.info.name), items: value)
            })
        }

        private func getSensorEntities(matching string: String? = nil) -> [Server: [IntentSensorsAppEntity]] {
            var sensorEntities: [Server: [IntentSensorsAppEntity]] = [:]
            let entities = ControlEntityProvider(domain: .sensor).getEntities(matching: string)

            for (server, values) in entities {
                sensorEntities[server] = values.map({ entity in
                    IntentSensorsAppEntity(
                        id: entity.id,
                        entityId: entity.entityId,
                        serverId: entity.serverId,
                        displayString: entity.name
                    )
                })
            }

            return sensorEntities
        }
    }
}