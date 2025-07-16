import Foundation
import UserNotifications

public extension UNAuthorizationOptions {
    static var defaultOptions: UNAuthorizationOptions {
        var opts: UNAuthorizationOptions = [.alert, .badge, .sound, .providesAppNotificationSettings]

        if !Current.isCatalyst {
            // we don't have provisioning for critical alerts in catalyst yet, and asking for permission errors
            opts.insert(.criticalAlert)
        }

        return opts
    }
}
