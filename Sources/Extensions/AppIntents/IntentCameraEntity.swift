import AppIntents
import Shared

@available(iOS 17.0, watchOS 10.0, *)
struct IntentCameraEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Camera")
    static let defaultQuery = IntentCameraEntityQuery()

    let id: String
    let serverId: String
    @Property(title: .init("app_intents.entity.property.entity_id", defaultValue: "Entity ID"))
    var entityId: String
    @Property(title: .init("app_intents.entity.property.name", defaultValue: "Name"))
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        .init(
            title: .init(stringLiteral: displayName),
            subtitle: .init(stringLiteral: entityId),
            image: .init(systemName: "camera")
        )
    }

    init(serverId: String, entityId: String, displayName: String) {
        self.id = "\(serverId)::\(entityId)"
        self.serverId = serverId
        self.entityId = entityId
        self.displayName = displayName
    }

    /// Rebuilds an entity from a persisted `serverId::entityId` identifier, for when the server can
    /// no longer be reached to describe it.
    init?(identifier: String) {
        let components = identifier.components(separatedBy: "::")
        guard components.count == 2 else {
            return nil
        }

        self.id = identifier
        self.serverId = components[0]
        self.entityId = components[1]
        self.displayName = components[1]
    }
}
