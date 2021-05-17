import ObjectMapper
import UserNotifications

public extension UNNotificationContent {
    private static var separator: String = "@duplicate_identifier-"

    static func uncombinedAction(from identifier: String) -> String {
        if identifier.contains(separator), let substring = identifier.components(separatedBy: separator).first {
            return substring
        } else {
            return identifier
        }
    }

    static func combinedAction(base: String, appended: String) -> String {
        [base, appended].joined(separator: String(Self.separator))
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

    var userInfoActions: [UNNotificationAction] {
        userInfoActionConfigs
            .map(NotificationAction.init(action:))
            .map(\.action)
    }
}
