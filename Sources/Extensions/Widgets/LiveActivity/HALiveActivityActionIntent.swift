#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import AppIntents
import Shared

@available(iOS 17.2, *)
struct HALiveActivityActionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "live_activity.perform_action.title"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "live_activity.perform_action.activity_id")
    var activityID: String

    @Parameter(title: "live_activity.perform_action.action_id")
    var actionID: String

    init() {}

    init(activityID: String, actionID: String) {
        self.activityID = activityID
        self.actionID = actionID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await Self.performAction(activityID: activityID, actionID: actionID, withoutAuthentication: false)
        return .result()
    }

    @MainActor
    static func performAction(activityID: String, actionID: String, withoutAuthentication: Bool) async throws {
        await Current.connectivity.refreshNetworkInformation()
        guard let activity = Activity<HALiveActivityAttributes>.activities.first(where: { $0.id == activityID }),
              [.active, .stale].contains(activity.activityState) else {
            throw ShortcutAppIntentError(L10n.Widgets.Custom.IntentPerformActionFailed.body)
        }
        try await sendAction(
            actionID: actionID,
            attributes: activity.attributes,
            state: activity.content.state,
            withoutAuthentication: withoutAuthentication
        )
    }

    @MainActor
    static func sendAction(
        actionID: String,
        attributes: HALiveActivityAttributes,
        state: HALiveActivityAttributes.ContentState,
        withoutAuthentication: Bool
    ) async throws {
        guard let action = state.actions.first(where: { $0.id == actionID }),
              !withoutAuthentication || !action.authenticationRequired else {
            throw ShortcutAppIntentError(L10n.Widgets.Custom.IntentPerformActionFailed.body)
        }
        guard let webhookID = attributes.serverWebhookId,
              let server = Current.servers.server(forWebhookID: webhookID),
              let api = Current.api(for: server) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        let event = api.mobileAppNotificationActionEvent(
            identifier: actionID,
            category: nil,
            actionData: ["tag": attributes.tag],
            textInput: nil
        )
        try await api.CreateEvent(eventType: event.eventType, eventData: event.eventData).async()
    }
}
#endif
