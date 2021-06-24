import UserNotifications
import XCGLogger

public extension XCGLogger {
    static var notifyUserInfoKey: String { "is_xcglogger_notify_category" }
    static var shouldNotifyUserDefaultsKey: String { "xcglogger_unnotifications" }

    func notify(
        _ closure: @autoclosure @escaping () -> String,
        functionName: StaticString = #function,
        fileName: StaticString = #fileID,
        lineNumber: Int = #line,
        log logLevel: XCGLogger.Level? = nil
    ) {
        guard !Current.isRunningTests else {
            return
        }

        if let level = logLevel {
            logln(closure(), level: level, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
        }

        guard Current.settingsStore.prefs.bool(forKey: Self.shouldNotifyUserDefaultsKey) else {
            return
        }

        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: UUID().uuidString,
            content: with(UNMutableNotificationContent()) {
                $0.title = String(describing: functionName)
                $0.subtitle = String(describing: fileName)
                $0.body = closure()
                $0.userInfo[Self.notifyUserInfoKey] = true
            },
            trigger: nil
        ), withCompletionHandler: nil)
    }
}
