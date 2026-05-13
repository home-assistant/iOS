import AppIntents
import Foundation
import HAKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 16.4, *)
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
        guard let request = HATypedRequest<HAResponseVoid>.executeMainAction(domain: domain, entityId: entityId) else {
            Current.Log
                .error(
                    "ToggleAppIntent: no main action for domain \(domain.rawValue), entityId: \(entityId), serverId: \(serverId)"
                )
            return .result()
        }
        AppIntentHaptics.notify()
        await withCheckedContinuation { continuation in
            connection.send(request).promise.pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume()
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to execute ToggleAppIntent, serverId: \(serverId), domain: \(domain), entityId: \(entityId), error: \(error)"
                        )
                    Current.notificationDispatcher.send(.init(
                        id: .intentToggleFailed,
                        title: L10n.Widgets.Custom.IntentToggleFailed.title,
                        body: L10n.Widgets.Custom.IntentToggleFailed.body
                    ))
                    continuation.resume()
                }
            }
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
