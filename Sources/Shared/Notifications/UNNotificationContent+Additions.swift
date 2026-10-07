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

    /// The URL this notification asks the app to open when `actionIdentifier` is chosen, if any.
    ///
    /// An action-specific `url` overrides the notification-wide one; the old-style dictionary form
    /// (`url: {identifier: url}`) is looked up by identifier, where
    /// `NotificationCategory.FallbackActionIdentifier` covers a plain tap.
    func urlString(forActionIdentifier actionIdentifier: String) -> String? {
        let urlValue = ["url", "uri", "clickAction"].compactMap { userInfo[$0] }.first

        if let action = userInfoActionConfigs.first(
            where: { $0.identifier.lowercased() == actionIdentifier.lowercased() }
        ), let url = action.url {
            // we only allow the action-specific one to override global if it's set
            return url
        } else if let openURLRaw = urlValue as? String {
            // global url [string], always do it if we aren't picking a specific action
            return openURLRaw
        } else if let openURLDictionary = urlValue as? [String: String] {
            // old-style, per-action url -- for before we could define actions in the notification dynamically
            return openURLDictionary.compactMap { key, value -> String? in
                if actionIdentifier == UNNotificationDefaultActionIdentifier,
                   key.lowercased() == NotificationCategory.FallbackActionIdentifier {
                    return value
                } else if key.lowercased() == actionIdentifier.lowercased() {
                    return value
                } else {
                    return nil
                }
            }.first
        } else {
            return nil
        }
    }

    var userInfoActions: [UNNotificationAction] {
        let payloadActions = userInfoPayloadActions.map(\.action)

        guard payloadActions.isEmpty else {
            return payloadActions
        }

        return Array(NotificationSnoozeAction.enabledActions().prefix(Self.maxUserInfoActions))
    }
}
