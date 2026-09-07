import AppIntents
import Foundation
import Shared

@available(macOS 13.0, watchOS 9.4, *)
struct TurnOffEntityAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.turn_off.title",
        defaultValue: "Turn off"
    )

    static let description = IntentDescription(.init(
        "app_intents.turn_off.description",
        defaultValue: "Turns off a light, switch or fan, or closes a cover"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("Turn off \(\.$entity)")
    }

    @Parameter(title: .init("app_intents.controllable_entity.parameter.entity", defaultValue: "Entity"))
    var entity: ControllableEntityAppEntity

    // The card is app-only: the view and the entity it draws aren't built for the watch, where a
    // spoken answer is the whole interaction anyway.
    #if os(watchOS)
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = try await ControlEntityIntentRunner.perform(.turnOff, on: entity)
        return .result(dialog: .init(stringLiteral: dialog))
    }
    #else
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let outcome = try await ControlEntityIntentRunner.performShowingResult(.turnOff, on: entity)
        return .result(dialog: .init(stringLiteral: outcome.dialog)) {
            if let state = outcome.state {
                ControlResultSnippetView(state: state)
            }
        }
    }
    #endif
}
