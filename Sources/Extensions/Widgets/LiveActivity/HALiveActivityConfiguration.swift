#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.2, *)
struct HALiveActivityConfiguration: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HALiveActivityAttributes.self) { context in
            HALockScreenView(attributes: context.attributes, state: context.state)
                .haLiveActivityLockScreenChrome(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            makeHADynamicIsland(attributes: context.attributes, state: context.state)
                .widgetURL(haLiveActivityTapURL(attributes: context.attributes, state: context.state))
        }
    }
}

@available(iOS 17.2, *)
extension View {
    func haLiveActivityLockScreenChrome(
        attributes: HALiveActivityAttributes,
        state: HALiveActivityAttributes.ContentState
    ) -> some View {
        activityBackgroundTint(HAActivityVisualStyle.backgroundColor(from: state.backgroundColor))
            .activitySystemActionForegroundColor(haLiveActivityForegroundColor(for: state))
            .widgetURL(haLiveActivityTapURL(attributes: attributes, state: state))
    }

    @available(iOS 18.0, *)
    func haLiveActivitySupplementalChrome(
        attributes: HALiveActivityAttributes,
        state: HALiveActivityAttributes.ContentState
    ) -> some View {
        activityBackgroundTint(HAActivityVisualStyle.supplementalBackgroundColor(from: state.backgroundColor))
            .activitySystemActionForegroundColor(haLiveActivitySupplementalForegroundColor(for: state))
            .widgetURL(haLiveActivityTapURL(attributes: attributes, state: state))
    }
}

/// The widget extension can't reliably resolve the server on a physical device, so it forwards
/// `webhook_id` and `url` for the app to resolve and navigate, instead of resolving here and
/// bailing the whole tap (url included) on failure.
@available(iOS 17.2, *)
func haLiveActivityTapURL(
    attributes: HALiveActivityAttributes,
    state: HALiveActivityAttributes.ContentState
) -> URL? {
    let webhookId = attributes.serverWebhookId
    Current.Log.verbose(
        "LiveActivity tapURL: hasServerWebhookId=\(webhookId != nil), hasURL=\(state.url?.isEmpty == false)"
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

@available(iOS 17.2, *)
private func haLiveActivityForegroundColor(for state: HALiveActivityAttributes.ContentState) -> Color? {
    HAActivityVisualStyle.foregroundColor(textColor: state.textColor, onBackground: state.backgroundColor)
}

@available(iOS 18.0, *)
private func haLiveActivitySupplementalForegroundColor(for state: HALiveActivityAttributes.ContentState) -> Color? {
    haLiveActivityForegroundColor(for: state) ?? HAActivityVisualStyle.defaultSupplementalForegroundColor
}
#endif
