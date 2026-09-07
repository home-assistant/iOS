import AppIntents
import Foundation
import Shared

/// Builds the card a control command shows once it has changed something.
///
/// The state is read back from the server rather than assumed: a command reports what the entity
/// *is* now, not what it was told to become, so a light that refused to turn on doesn't show a card
/// claiming otherwise.
@available(macOS 13.0, watchOS 9.4, *)
enum ControlResultSnippet {
    static func state(
        of context: some EntityContextRepresentable,
        serverId: String,
        iconName: String
    ) async -> HAEntityStateAppEntity? {
        guard let server = Current.servers.server(for: .init(rawValue: serverId)),
              let liveState = try? await AppIntentServerAPI.entityState(
                  server: server,
                  entityId: context.entityId
              ) else {
            // The command already succeeded; failing to read the state back is not worth failing it,
            // so the spoken sentence stands on its own and no card is shown.
            return nil
        }
        return HAEntityStateAppEntity(
            context: context,
            serverId: serverId,
            serverName: server.info.name,
            iconName: iconName,
            state: liveState
        )
    }
}
