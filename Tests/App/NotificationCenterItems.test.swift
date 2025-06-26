import Shared
import Testing

struct NotificationCenterItemsTests {
    @Test func testNotificationNamesRawValues() async throws {
        // General notification names
        assert(NotificationCenterItems.apiDidConnectNotification.rawValue == "HomeAssistantAPIConnected")
        assert(NotificationCenterItems.assistLaunchNotification.rawValue == "assist-detault-complication-launch")
        assert(
            NotificationCenterItems.MJPEGStreamerDidReceiveResponse
                .rawValue == "MJPEGStreamerSessionDelegateDidReceiveResponse"
        )
        assert(
            NotificationCenterItems.notificationCommandManagerDidUpdateComplicationsNotification
                .rawValue == "didUpdateComplicationsNotification"
        )
        assert(NotificationCenterItems.localPushManagerStateDidChange.rawValue == "LocalPushManagerStateDidChange")
        assert(NotificationCenterItems.webViewRelatedSettingDidChange.rawValue == "webViewRelatedSettingDidChange")
        assert(NotificationCenterItems.menuRelatedSettingDidChange.rawValue == "menuRelatedSettingDidChange")
        assert(NotificationCenterItems.locationRelatedSettingDidChange.rawValue == "locationRelatedSettingDidChange")

        // macOS-related notification names
        assert(NotificationCenterItems.macScreenSaverDidStart.rawValue == "com.apple.screensaver.didstart")
        assert(NotificationCenterItems.macScreenSaverDidStop.rawValue == "com.apple.screensaver.didstop")
        assert(NotificationCenterItems.macScreenIsLocked.rawValue == "com.apple.screenIsLocked")
        assert(NotificationCenterItems.macScreenIsUnlocked.rawValue == "com.apple.screenIsUnlocked")
        assert(NotificationCenterItems.macWorkspaceWillSleep.rawValue == "NSWorkspaceWillSleepNotification")
        assert(NotificationCenterItems.macWorkspaceDidWake.rawValue == "NSWorkspaceDidWakeNotification")
        assert(NotificationCenterItems.macWorkspaceScreensDidSleep.rawValue == "NSWorkspaceScreensDidSleepNotification")
        assert(NotificationCenterItems.macWorkspaceScreensDidWake.rawValue == "NSWorkspaceScreensDidWakeNotification")
        assert(
            NotificationCenterItems.macWorkspaceSessionDidResignActive
                .rawValue == "NSWorkspaceSessionDidResignActiveNotification"
        )
        assert(
            NotificationCenterItems.macWorkspaceSessionDidBecomeActive
                .rawValue == "NSWorkspaceSessionDidBecomeActiveNotification"
        )
        assert(
            NotificationCenterItems.nonMacTerminationWillBeginNotification
                .rawValue == "NSApplicationWillTerminateNotification"
        )
    }
}
