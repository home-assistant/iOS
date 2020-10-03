import XCGLogger
import UserNotifications

extension XCGLogger {
    public static var notifyUserInfoKey: String { "is_xcglogger_notify_category" }
    public static var shouldNotifyUserDefaultsKey: String { "xcglogger_unnotifications" }

    public func notify(
        _ closure: @autoclosure () -> String,
        functionName: StaticString = #function,
        fileName: StaticString = #file,
        lineNumber: Int = #line
    ) {
        guard !Current.isRunningTests else {
            return
        }

        guard Current.settingsStore.prefs.bool(forKey: Self.shouldNotifyUserDefaultsKey) else {
            return
        }

        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: UUID().uuidString,
            content: with(UNMutableNotificationContent()) {
                $0.title = String(describing: functionName)
                $0.body = closure()
                $0.userInfo[Self.notifyUserInfoKey] = true
            },
            trigger: nil
        ), withCompletionHandler: nil)
    }
}
