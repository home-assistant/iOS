import AppIntents
import Foundation
import Shared

/// Answers "what lights are on" by listing the entities of a kind that are currently active.
@available(macOS 13.0, *)
struct GetActiveEntitiesAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.active_entities.title",
        defaultValue: "Get what is on"
    )

    static let description = IntentDescription(.init(
        "app_intents.active_entities.description",
        defaultValue: "Lists the entities of a kind that are currently in the state you ask for"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$filter) that are \(\.$state)")
    }

    @Parameter(
        title: .init("app_intents.active_entities.filter.name", defaultValue: "Kind"),
        default: .all
    )
    var filter: ActiveEntitiesFilterAppEnum

    @Parameter(
        title: .init("app_intents.active_entities.state.name", defaultValue: "State"),
        default: .on
    )
    var state: EntityStateFilterAppEnum

    func perform() async throws -> some IntentResult & ReturnsValue<[HAEntityStateAppEntity]> & ProvidesDialog {
        await Current.connectivity.refreshNetworkInformation()
        let active = try await ActiveEntitiesFinder.active(matching: filter, state: state)
        return .result(
            value: active,
            dialog: .init(stringLiteral: ActiveEntitiesFinder.dialog(for: active, filter: filter, state: state))
        )
    }
}
