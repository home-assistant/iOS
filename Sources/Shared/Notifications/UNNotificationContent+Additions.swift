import UserNotifications
import ObjectMapper

public extension UNNotificationContent {
    var userInfoActions: [UNNotificationAction] {
        let actions = userInfo["actions"] as? [[String: Any]] ?? []
        do {
            return try Mapper<MobileAppConfigPushCategory.Action>()
                .mapArray(JSONArray: actions)
                .map(NotificationAction.init(action:))
                .map(\.action)
        } catch {
            return []
        }
    }
}
