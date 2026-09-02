import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

struct CustomWidgetToggleAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle"
    static var isDiscoverable: Bool = false

    // No translation needed below, this is not a discoverable intent
    @Parameter(title: "Server")
    var serverId: String?
    @Parameter(title: "Domain")
    var domain: String?
    @Parameter(title: "Entity ID")
    var entityId: String?
    @Parameter(title: "Is widget showing states?")
    var widgetShowingStates: Bool?

    func perform() async throws -> some IntentResult {
        Current.Log.verbose(
            "ToggleAppIntent: perform started, serverId: \(String(describing: serverId)), domain: \(String(describing: domain)), entityId: \(String(describing: entityId)), widgetShowingStates: \(String(describing: widgetShowingStates))"
        )
        guard let serverId,
              let domainString = domain,
              let entityId,
              let widgetShowingStates else {
            Current.Log
                .error(
                    "ToggleAppIntent: missing parameters, serverId: \(String(describing: serverId)), domain: \(String(describing: domain)), entityId: \(String(describing: entityId)), widgetShowingStates: \(String(describing: widgetShowingStates))"
                )
            return .result()
        }
        guard let domain = Domain(rawValue: domainString) else {
            Current.Log.error("ToggleAppIntent: unknown domain '\(domainString)', entityId: \(entityId)")
            return .result()
        }
        guard let connection = CustomWidgetIntentHelper.resolveConnection(
            serverId: serverId,
            intentName: "ToggleAppIntent"
        ) else {
            return .result()
        }
        guard domain.canToggle else {
            Current.Log.error(
                "ToggleAppIntent: \(domain.rawValue) cannot be toggled, entityId: \(entityId), serverId: \(serverId)"
            )
            return .result()
        }
        Current.Log.verbose(
            "ToggleAppIntent: toggling, serverId: \(serverId), domain: \(domain.rawValue), entityId: \(entityId)"
        )
        AppIntentHaptics.notify()
        do {
            // The frontend's toggle: the entity's state decides between the domain's on and off
            // services, so a locked lock unlocks and a running script stops.
            try await EntityToggler.toggle(domain: domain, entityId: entityId, connection: connection)
            Current.Log.verbose(
                "ToggleAppIntent: toggled, serverId: \(serverId), domain: \(domain.rawValue), entityId: \(entityId)"
            )
        } catch {
            Current.Log
                .error(
                    "Failed to execute ToggleAppIntent, serverId: \(serverId), domain: \(domain), entityId: \(entityId), error: \(error)"
                )
            Current.notificationDispatcher.send(.init(
                id: .intentToggleFailed,
                title: L10n.Widgets.Custom.IntentToggleFailed.title,
                body: L10n.Widgets.Custom.IntentToggleFailed.body
            ))
        }
        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()
        if widgetShowingStates {
            /* Since when you toggle an entity not always it reflects the new state right away
             and at the same time push notifications to update widgets are currently not working reliably
             in iOS, this delay is out best effort for the user to see the correct state after finishing the interaction */
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return .result()
    }
}
