import ObjectMapper
import UserNotifications

public extension UNNotificationContent {
    private static let separator: String = "@duplicate_identifier-"

    static func uncombinedAction(from identifier: String) -> String {
        if identifier.contains(separator), let substring = identifier.components(separatedBy: separator).first {
            return substring
        } else {
            return identifier
        }
    }

    static func combinedAction(base: String, appended: String) -> String {
        [base, appended].joined(separator: String(separator))
    }

    var userInfoActionConfigs: [MobileAppConfigPushCategory.Action] {
        let actions = userInfo["actions"] as? [[String: Any]] ?? []

        do {
            return try Mapper<MobileAppConfigPushCategory.Action>()
                .mapArray(JSONArray: actions)
                .reduce(into: []) { result, original in
                    var trailing = (2...).lazy.map(String.init(describing:)).makeIterator()
                    var action = original

                    while result.contains(where: { $0.identifier == action.identifier }) {
                        action.identifier = Self.combinedAction(base: original.identifier, appended: trailing.next()!)
                    }

                    result.append(action)
                }
        } catch {
            return []
        }
    }

    /// The most actions a notification can offer; anything beyond this is dropped by the system.
    static let maxUserInfoActions = 10

    /// The payload's actions as our own model, deduplicated and capped. `userInfoActions` is the
    /// `UNNotificationAction` form of this; the watch needs the model itself so it can tell a
    /// text-input action apart and drive it on its own (see `DynamicNotificationHostingController`).
    var userInfoPayloadActions: [NotificationAction] {
        Array(userInfoActionConfigs.map(NotificationAction.init(action:)).prefix(Self.maxUserInfoActions))
    }

    var userInfoActions: [UNNotificationAction] {
        let payloadActions = userInfoPayloadActions.map(\.action)

        guard payloadActions.isEmpty else {
            return payloadActions
        }

        return Array(NotificationSnoozeAction.enabledActions().prefix(Self.maxUserInfoActions))
    }
}
