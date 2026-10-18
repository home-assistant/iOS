import AppIntents
import Foundation
import Shared

/// Opens an entity's more-info dialog in the frontend.
///
/// Spotlight runs this intent when someone taps one of the indexed entities, which is why it exists
/// separately from the widget control's `OpenEntityAppIntent`: only an `OpenIntent` with a `target`
/// parameter is picked up for that. `HomeAssistantAppShortcuts` offers it by voice too, so asking for
/// an entity lands on the same dialog as tapping its search result.
///
/// What is offered out loud is the same list a question about a state gets; what a Spotlight tap
/// hands over resolves through the entity's own query, which stays as wide as the index.
@available(macOS 13.0, *)
struct ShowEntityDetailsAppIntent: OpenIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.show_entity_details.title",
        defaultValue: "Show Entity Details"
    )

    @Parameter(
        title: .init("app_intents.show_entity_details.parameter.entity", defaultValue: "Entity"),
        optionsProvider: ReadableEntityOptionsProvider()
    )
    var target: HAAppEntityAppIntentEntity

    func perform() async throws -> some IntentResult {
        guard let url = AppConstants.openEntityDestinationURL(
            entityId: target.entityId,
            serverId: target.serverId
        ) else {
            return .result()
        }
        await MainActor.run {
            URLOpener.shared.open(url, options: [:], completionHandler: nil)
        }
        return .result()
    }
}
