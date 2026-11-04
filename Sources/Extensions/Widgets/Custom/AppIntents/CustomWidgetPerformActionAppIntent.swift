import AppIntents
import Foundation
import Shared
import SwiftUI

/// Runs a magic item's "perform action" behavior from a widget tile.
///
/// Calling `domain.service` with a payload is what `PerformActionAppIntent` — the discoverable
/// Shortcuts action — already does, transport choice included, so this hands the item's stored
/// action over to it and only adds what a tile needs around the call: haptics, a notification when
/// it fails, and clearing the tile's pending confirmation afterwards.
@available(iOS 17.0, *)
struct CustomWidgetPerformActionAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Perform action"
    static var isDiscoverable: Bool = false

    // No translation needed below, this is not a discoverable intent
    @Parameter(title: "Server")
    var serverId: String?
    /// The action to call, as `domain.service` — e.g. `light.turn_on`.
    @Parameter(title: "Action ID")
    var actionId: String?
    @Parameter(title: "Action data")
    var payload: String?

    func perform() async throws -> some IntentResult {
        Current.Log.verbose(
            "PerformActionAppIntent (widget): perform started, serverId: \(String(describing: serverId)), actionId: \(String(describing: actionId))"
        )
        guard let serverId, let actionId else {
            Current.Log.error(
                "PerformActionAppIntent (widget): missing parameters, serverId: \(String(describing: serverId)), actionId: \(String(describing: actionId))"
            )
            return .result()
        }
        // The entity is rebuilt from the stored identifier instead of the server's action list: a
        // widget tap can't wait on a round trip just to describe the action it already knows.
        guard let action = IntentActionEntity(identifier: "\(serverId)::\(actionId)") else {
            Current.Log.error("PerformActionAppIntent (widget): unusable action id '\(actionId)'")
            return .result()
        }

        AppIntentHaptics.notify()

        var intent = PerformActionAppIntent()
        intent.server = IntentServerAppEntity(identifier: Identifier<Server>(rawValue: serverId))
        intent.action = action
        intent.payload = payload ?? "{}"

        do {
            _ = try await intent.perform()
            Current.Log.verbose(
                "PerformActionAppIntent (widget): action succeeded, serverId: \(serverId), actionId: \(actionId)"
            )
        } catch {
            Current.Log.error(
                "Failed to execute PerformActionAppIntent (widget), serverId: \(serverId), actionId: \(actionId), error: \(error)"
            )
            Current.notificationDispatcher.send(.init(
                id: .intentPerformActionFailed,
                title: L10n.Widgets.Custom.IntentPerformActionFailed.title,
                body: L10n.Widgets.Custom.IntentPerformActionFailed.body
            ))
        }

        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()
        return .result()
    }
}
