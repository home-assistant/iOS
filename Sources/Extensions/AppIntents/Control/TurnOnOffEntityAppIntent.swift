import AppIntents
import Foundation
import Shared

/// Switches an entity on or off.
///
/// One intent for both directions, the way opening and closing a cover is one: the service still
/// comes from the entity's domain, so this turns on a light and opens a cover.
@available(macOS 13.0, watchOS 9.4, *)
struct TurnOnOffEntityAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.turn_on_off.title",
        defaultValue: "Turn on, off or toggle"
    )

    static let description = IntentDescription(.init(
        "app_intents.turn_on_off.description",
        defaultValue: "Turns a light, switch or fan on or off, or opens and closes a cover"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$action) \(\.$entity)")
    }

    @Parameter(title: .init("app_intents.turn_on_off.action.name", defaultValue: "Action"), default: .on)
    var action: TurnOnOffActionAppEnum

    @Parameter(title: .init("app_intents.controllable_entity.parameter.entity", defaultValue: "Entity"))
    var entity: ControllableEntityAppEntity

    init() {}

    /// Used by the App Shortcuts, which need the direction fixed so the phrase can name the entity.
    init(action: TurnOnOffActionAppEnum) {
        self.action = action
    }

    // The card is app-only: the view and the entity it draws aren't built for the watch, where a
    // spoken answer is the whole interaction anyway.
    #if os(watchOS)
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = try await ControlEntityIntentRunner.perform(action.runnerAction, on: entity)
        return .result(dialog: .init(stringLiteral: dialog))
    }
    #else
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let outcome = try await ControlEntityIntentRunner.performShowingResult(action.runnerAction, on: entity)
        return .result(dialog: .init(stringLiteral: outcome.dialog)) {
            if let state = outcome.state {
                ControlResultSnippetView(state: state)
            }
        }
    }
    #endif
}
