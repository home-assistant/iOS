import AppIntents
import Foundation
import Shared

@available(macOS 13.0, watchOS 9.4, *)
struct ToggleEntityAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.toggle.title",
        defaultValue: "Toggle"
    )

    static let description = IntentDescription(.init(
        "app_intents.toggle.description",
        defaultValue: "Flips an entity to its opposite state"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle \(\.$entity)")
    }

    @Parameter(title: .init("app_intents.controllable_entity.parameter.entity", defaultValue: "Entity"))
    var entity: ControllableEntityAppEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = try await ControlEntityIntentRunner.perform(.toggle, on: entity)
        return .result(dialog: .init(stringLiteral: dialog))
    }
}
