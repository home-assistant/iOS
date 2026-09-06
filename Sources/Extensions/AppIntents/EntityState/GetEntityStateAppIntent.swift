import AppIntents
import Foundation
import Shared
import SwiftUI

/// Reads an entity's live state, returning it as typed properties Siri and Shortcuts can read.
@available(macOS 13.0, *)
struct GetEntityStateAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.entity_state.title",
        defaultValue: "Get entity state"
    )

    static let description = IntentDescription(.init(
        "app_intents.entity_state.description",
        defaultValue: "Reads the current state of a Home Assistant entity"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("Get the state of \(\.$entity)")
    }

    @Parameter(title: .init("app_intents.entity_state.parameter.entity", defaultValue: "Entity"))
    var entity: HAAppEntityAppIntentEntity

    func perform() async throws -> some IntentResult & ReturnsValue<HAEntityStateAppEntity> & ProvidesDialog &
        ShowsSnippetView {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.server(for: .init(rawValue: entity.serverId)) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        let liveState = try await AppIntentServerAPI.entityState(server: server, entityId: entity.entityId)
        let result = HAEntityStateAppEntity(entity: entity, state: liveState)
        return .result(
            value: result,
            dialog: .init(stringLiteral: L10n.AppIntents.EntityState.Dialog.content(
                result.name,
                result.formattedState
            )),
            view: EntityStateSnippetView(state: result)
        )
    }
}
