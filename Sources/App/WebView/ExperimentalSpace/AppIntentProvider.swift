import AppIntents
import Foundation
import Shared

@available(iOS 18.0, *)
/// A service that provides the appropriate AppIntent for a given HAAppEntity
enum AppIntentProvider {
    /// Returns an AppIntent configured for the given entity and server
    /// - Parameters:
    ///   - appEntity: The HAAppEntity to create an intent for
    ///   - server: The server the entity belongs to
    /// - Returns: An AppIntent configured for the entity's domain
    static func intent(for appEntity: HAAppEntity, server: Server) -> any AppIntent {
        let domain = Domain(entityId: appEntity.entityId)

        switch domain {
        case .light:
            return lightIntent(for: appEntity, server: server)
        case .cover:
            return coverIntent(for: appEntity, server: server)
        case .switch, .inputBoolean:
            return switchIntent(for: appEntity, server: server)
        case .fan:
            return fanIntent(for: appEntity, server: server)
        default:
            // Default fallback - returns a switch intent as a safe default
            // since it handles multiple domains including input_boolean
            return switchIntent(for: appEntity, server: server)
        }
    }

    // MARK: - Private Intent Builders

    private static func lightIntent(for appEntity: HAAppEntity, server: Server) -> LightIntent {
        let intent = LightIntent()
        intent.light = .init(
            id: appEntity.entityId,
            entityId: appEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: appEntity.name,
            iconName: appEntity.icon ?? ""
        )
        intent.toggle = true
        intent.value = false // Default value when toggle is true
        return intent
    }

    private static func coverIntent(for appEntity: HAAppEntity, server: Server) -> CoverIntent {
        let intent = CoverIntent()
        intent.entity = .init(
            id: appEntity.entityId,
            entityId: appEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: appEntity.name,
            iconName: appEntity.icon ?? ""
        )
        intent.toggle = true
        intent.value = false // Default value when toggle is true
        return intent
    }

    private static func switchIntent(for appEntity: HAAppEntity, server: Server) -> SwitchIntent {
        let intent = SwitchIntent()
        intent.entity = .init(
            id: appEntity.entityId,
            entityId: appEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: appEntity.name,
            iconName: appEntity.icon ?? ""
        )
        intent.toggle = true
        intent.value = false // Default value when toggle is true
        return intent
    }

    private static func fanIntent(for appEntity: HAAppEntity, server: Server) -> FanIntent {
        let intent = FanIntent()
        intent.fan = .init(
            id: appEntity.entityId,
            entityId: appEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: appEntity.name,
            iconName: appEntity.icon ?? ""
        )
        intent.toggle = true
        intent.value = false // Default value when toggle is true
        return intent
    }
}
