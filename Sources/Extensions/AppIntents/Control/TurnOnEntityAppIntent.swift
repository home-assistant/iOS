import AppIntents
import Foundation
import Shared

@available(macOS 13.0, watchOS 9.4, *)
struct TurnOnEntityAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.turn_on.title",
        defaultValue: "Turn on"
    )

    static let description = IntentDescription(.init(
        "app_intents.turn_on.description",
        defaultValue: "Turns on a light, switch or fan, or opens a cover"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("Turn on \(\.$entity)")
    }

    @Parameter(title: .init("app_intents.controllable_entity.parameter.entity", defaultValue: "Entity"))
    var entity: ControllableEntityAppEntity

    // The card is app-only: the view and the entity it draws aren't built for the watch, where a
    // spoken answer is the whole interaction anyway.
    #if os(watchOS)
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = try await ControlEntityIntentRunner.perform(.turnOn, on: entity)
        return .result(dialog: .init(stringLiteral: dialog))
    }
    #else
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let outcome = try await ControlEntityIntentRunner.performShowingResult(.turnOn, on: entity)
        return .result(dialog: .init(stringLiteral: outcome.dialog)) {
            if let state = outcome.state {
                ControlResultSnippetView(state: state)
            }
        }
    }
    #endif
}
