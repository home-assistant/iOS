import UserNotifications
import ObjectMapper

public extension UNNotificationContent {
    var userInfoActionConfigs: [MobileAppConfigPushCategory.Action] {
        let actions = userInfo["actions"] as? [[String: Any]] ?? []
        do {
            return try Mapper<MobileAppConfigPushCategory.Action>().mapArray(JSONArray: actions)
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
