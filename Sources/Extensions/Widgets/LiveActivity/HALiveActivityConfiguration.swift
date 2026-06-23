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

    /// The widget extension can't reliably resolve the server on a physical device, so it forwards
    /// `webhook_id` and `url` for the app to resolve and navigate, instead of resolving here and
    /// bailing the whole tap (url included) on failure.
    private static func tapURL(
        attributes: HALiveActivityAttributes,
        state: HALiveActivityAttributes.ContentState
    ) -> URL? {
        let webhookId = attributes.serverWebhookId
        Current.Log.verbose(
            "LiveActivity tapURL: serverWebhookId=\(webhookId ?? "nil"), hasURL=\(state.url?.isEmpty == false)"
        )

        var items: [URLQueryItem] = []
        if let webhookId, !webhookId.isEmpty {
            items.append(URLQueryItem(name: "webhook_id", value: webhookId))
        }
        if let rawInput = state.url, !rawInput.isEmpty {
            items.append(URLQueryItem(name: "url", value: rawInput))
        }
        guard !items.isEmpty else { return nil }

        var components = URLComponents(string: "\(AppConstants.deeplinkURL.absoluteString)navigate")
        components?.queryItems = items
        return components?.url?.withWidgetAuthenticity()
    }
}
#endif
