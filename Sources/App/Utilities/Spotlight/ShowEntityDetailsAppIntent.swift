import AppIntents
import Foundation
import Shared

/// Opens an entity's more-info dialog in the frontend (or the native player, for cameras).
///
/// Spotlight runs this intent when someone taps one of the indexed entities, which is why it exists
/// separately from the widget control's `OpenEntityAppIntent`: only an `OpenIntent` with a `target`
/// parameter is picked up for that.
@available(macOS 13.0, *)
struct ShowEntityDetailsAppIntent: OpenIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.show_entity_details.title",
        defaultValue: "Show Entity Details"
    )

    @Parameter(
        title: .init("app_intents.show_entity_details.parameter.entity", defaultValue: "Entity")
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
