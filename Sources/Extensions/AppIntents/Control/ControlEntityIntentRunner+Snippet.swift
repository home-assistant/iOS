import AppIntents
import Foundation
import Shared

/// The card side of the control commands, kept apart from the runner because the entity it builds
/// and the view that draws it are in the app only — the runner itself also builds for the watch.
@available(macOS 13.0, *)
extension ControlEntityIntentRunner {
    /// The sentence to speak, plus the entity as it stands once the command has run.
    ///
    /// The state is read back rather than assumed, so the card reports what the entity *is* and not
    /// what it was told to become. Failing to read it back does not fail the command: the action
    /// already happened, so the sentence stands on its own and no card is shown.
    static func performShowingResult(
        _ action: Action,
        on entity: ControllableEntityAppEntity
    ) async throws -> (dialog: String, state: HAEntityStateAppEntity?) {
        let service = try await callService(action, on: entity)
        let state = await ControlResultSnippet.state(
            of: entity,
            serverId: entity.serverId,
            iconName: entity.iconName,
            settlingOn: entity.domain?.statesAfter(service) ?? []
        )
        return (dialog(for: service, entityName: entity.displayString), state)
    }
}
