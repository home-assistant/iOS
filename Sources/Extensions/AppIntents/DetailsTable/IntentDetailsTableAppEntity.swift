import AppIntents
import Foundation
import Shared
import SFSafeSymbols


@available(iOS 17.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct IntentDetailsTableAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "DETAIL TABLE")


    static let defaultQuery = IntentDetailsTableAppEntityQuery()

    // UniqueID: serverId-entityId
    var id: String
    var entityId: String
    var serverId: String
    var displayString: String
    var iconName: String
    
    var displayRepresentation: DisplayRepresentation {
        
        DisplayRepresentation(title: "\(displayString)")
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.displayString = displayString
        self.iconName = iconName
    }
    
    
    struct IntentDetailsTableAppEntityQuery: EntityQuery, EntityStringQuery {
        func entities(for identifiers: [IntentDetailsTableAppEntity.ID]) async throws -> [IntentDetailsTableAppEntity] {
            getSensorEntities().flatMap(\.value).filter { identifiers.contains($0.id) }
        }

        func entities(matching string: String) async throws -> IntentItemCollection<IntentDetailsTableAppEntity> {
            let sensorsPerServer = getSensorEntities()

            return .init(sections: sensorsPerServer.map { (key: Server, value: [IntentDetailsTableAppEntity]) in
                .init(
                    .init(stringLiteral: key.info.name),
                    items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
                )
            })
        }

        func suggestedEntities() async throws -> IntentItemCollection<IntentDetailsTableAppEntity> {
            let sensorsPerServer = getSensorEntities()
            
            return .init(sections: sensorsPerServer.map { (key: Server, value: [IntentDetailsTableAppEntity]) in
                .init(.init(stringLiteral: key.info.name), items: value)
            })
        }

        
        private func getSensorEntities(matching string: String? = nil) -> [Server: [IntentDetailsTableAppEntity]] {
            var lightEntities: [Server: [IntentDetailsTableAppEntity]] = [:]
            let entities = ControlEntityProvider(domain: .sensor).getEntities(matching: string)

            for (server, values) in entities {
                lightEntities[server] = values.map({ entity in
                    IntentDetailsTableAppEntity(
                        id: entity.id,
                        entityId: entity.entityId,
                        serverId: entity.serverId,
                        displayString: entity.name,
                        iconName: entity.icon ?? SFSymbol.lightbulbFill.rawValue
                    )
                })
            }

            return lightEntities
        }
    }
}

