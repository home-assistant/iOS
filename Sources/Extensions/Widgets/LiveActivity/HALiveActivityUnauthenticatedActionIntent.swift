#if os(iOS) && !targetEnvironment(macCatalyst)
import AppIntents

@available(iOS 17.2, *)
struct HALiveActivityUnauthenticatedActionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "live_activity.perform_action.title"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

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
        try await HALiveActivityActionIntent.performAction(
            activityID: activityID,
            actionID: actionID,
            withoutAuthentication: true
        )
        return .result()
    }
}
#endif
