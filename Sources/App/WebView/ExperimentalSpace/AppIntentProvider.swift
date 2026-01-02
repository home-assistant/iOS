import AppIntents
import Foundation
import HAKit
import Shared

@available(iOS 18.0, *)
/// A service that provides the appropriate AppIntent for a given HAEntity
enum AppIntentProvider {
    /// Returns an AppIntent configured for the given entity and server
    /// - Parameters:
    ///   - haEntity: The HAEntity to create an intent for
    ///   - server: The server the entity belongs to
    /// - Returns: An AppIntent configured for the entity's domain
    static func intent(for haEntity: HAEntity, server: Server) -> any AppIntent {
        let domain = Domain(entityId: haEntity.entityId)

        switch domain {
        case .light:
            return lightIntent(for: haEntity, server: server)
        case .cover:
            return coverIntent(for: haEntity, server: server)
        case .switch, .inputBoolean:
            return switchIntent(for: haEntity, server: server)
        case .fan:
            return fanIntent(for: haEntity, server: server)
        default:
            // Default fallback - returns a switch intent as a safe default
            // since it handles multiple domains including input_boolean
            return switchIntent(for: haEntity, server: server)
        }
    }

    // MARK: - Private Intent Builders

    private static func lightIntent(for haEntity: HAEntity, server: Server) -> LightIntent {
        let intent = LightIntent()
        intent.light = .init(
            id: haEntity.entityId,
            entityId: haEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: haEntity.attributes.friendlyName ?? haEntity.entityId,
            iconName: haEntity.attributes.icon ?? ""
        )
        intent.toggle = true
        intent.value = false // Default value when toggle is true
        return intent
    }

    private static func coverIntent(for haEntity: HAEntity, server: Server) -> CoverIntent {
        let intent = CoverIntent()
        intent.entity = .init(
            id: haEntity.entityId,
            entityId: haEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: haEntity.attributes.friendlyName ?? haEntity.entityId,
            iconName: haEntity.attributes.icon ?? ""
        )
        intent.toggle = true
        intent.value = false // Default value when toggle is true
        return intent
    }

    private static func switchIntent(for haEntity: HAEntity, server: Server) -> SwitchIntent {
        let intent = SwitchIntent()
        intent.entity = .init(
            id: haEntity.entityId,
            entityId: haEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: haEntity.attributes.friendlyName ?? haEntity.entityId,
            iconName: haEntity.attributes.icon ?? ""
        )
        intent.toggle = true
        intent.value = false // Default value when toggle is true
        return intent
    }

    private static func fanIntent(for haEntity: HAEntity, server: Server) -> FanIntent {
        let intent = FanIntent()
        intent.fan = .init(
            id: haEntity.entityId,
            entityId: haEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: haEntity.attributes.friendlyName ?? haEntity.entityId,
            iconName: haEntity.attributes.icon ?? ""
        )
        intent.toggle = true
        intent.value = false // Default value when toggle is true
        return intent
    }
}
