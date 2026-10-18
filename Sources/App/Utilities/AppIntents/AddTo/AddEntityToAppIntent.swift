import AppIntents
import Foundation
import Shared

/// Adds an entity to the Apple Watch, CarPlay quick access or the Mac toolbar.
///
/// This is the frontend's "Add to" sheet as an intent, which is what puts it within reach of the
/// entity the web view reports as being on screen: with the more info dialog open, "add this to my
/// watch" has an entity to mean.
///
/// One intent with a destination parameter rather than one intent per destination, matching
/// `TurnOnOffEntityAppIntent`: the goal is the same either way, and Shortcuts reads better as a
/// single "Add … to …" row.
///
/// iOS 17 is where `IntentParameterDependency` arrived, which is what lets the destination list see
/// the entity that was chosen and drop the destinations that cannot show it.
@available(iOS 17.0, macOS 14.0, *)
struct AddEntityToAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.add_to.title",
        defaultValue: "Add entity to"
    )

    static let description = IntentDescription(.init(
        "app_intents.add_to.description",
        defaultValue: "Adds a Home Assistant entity to the Apple Watch, CarPlay quick access or the Mac toolbar"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$entity) to \(\.$destination)")
    }

    @Parameter(title: .init("app_intents.add_to.entity.name", defaultValue: "Entity"))
    var entity: HAAppEntityAppIntentEntity

    @Parameter(
        title: .init("app_intents.add_to.destination.name", defaultValue: "Destination"),
        optionsProvider: EntityAddToDestinationOptionsProvider()
    )
    var destination: EntityAddToDestinationAppEnum

    init() {}

    /// On the main actor for the device checks, which read `UIDevice`. The writes underneath are a
    /// single small config row each, the same ones the frontend's sheet performs from here.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard destination.isAvailable else {
            throw ShortcutAppIntentError(
                L10n.AppIntents.AddTo.Error.unavailable(destination.localizedName)
            )
        }
        guard destination.supports(entityId: entity.entityId) else {
            throw ShortcutAppIntentError(
                L10n.AppIntents.AddTo.Error.unsupported(entity.displayString, destination.localizedName)
            )
        }

        let outcome = try EntityAddToConfigWriter.add(
            entityId: entity.entityId,
            serverId: entity.serverId,
            to: destination
        )
        let dialog = switch outcome {
        case .added:
            L10n.AppIntents.AddTo.Dialog.added(entity.displayString, destination.localizedName)
        case .alreadyPresent:
            L10n.AppIntents.AddTo.Dialog.alreadyAdded(entity.displayString, destination.localizedName)
        }
        return .result(dialog: .init(stringLiteral: dialog))
    }
}
