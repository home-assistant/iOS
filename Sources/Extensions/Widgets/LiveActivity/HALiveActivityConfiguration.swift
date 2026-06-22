#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.2, *)
struct HALiveActivityConfiguration: Widget {
    /// Adaptive Lock Screen surface that matches the current system appearance.
    private static let lockScreenBackground = Color(uiColor: .systemBackground)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HALiveActivityAttributes.self) { context in
            HALockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Self.lockScreenBackground)
            .activitySystemActionForegroundColor(Color.primary)
            .widgetURL(Self.tapURL(attributes: context.attributes, state: context.state))
        } dynamicIsland: { context in
            makeHADynamicIsland(attributes: context.attributes, state: context.state)
                .widgetURL(Self.tapURL(attributes: context.attributes, state: context.state))
        }
    }

    /// Deep link opened when the activity is tapped. Opens the server that started the activity
    /// and, when the state carries a `url` (mirroring actionable notifications), navigates to that
    /// HA path. Returns `nil` — no tap target, so the system just launches the app — when there is
    /// no server id or it no longer maps to a known server.
    private static func tapURL(
        attributes: HALiveActivityAttributes,
        state: HALiveActivityAttributes.ContentState
    ) -> URL? {
        guard
            let webhookId = attributes.serverWebhookId,
            let server = Current.servers.server(forWebhookID: webhookId) else { return nil }
        let serverId = server.identifier.rawValue

        if let path = state.url, !path.isEmpty {
            let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
            return AppConstants.navigateDeeplinkURL(
                path: normalized,
                serverId: serverId,
                avoidUnnecessaryReload: true
            )?.withWidgetAuthenticity()
        }
        return AppConstants.openPageDeeplinkURL(path: "", serverId: serverId)
    }
}
#endif
