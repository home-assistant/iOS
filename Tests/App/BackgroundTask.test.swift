import Shared
import Testing

struct BackgroundTaskTests {
    @Test func testAllCasesRawValues() async throws {
        assert(BackgroundTask.backgroundFetch.rawValue == "background-fetch")
        assert(BackgroundTask.lifecycleManagerDidFinishLaunching.rawValue == "lifecycle-manager-didFinishLaunching")
        assert(BackgroundTask.lifecycleManagerDidEnterBackground.rawValue == "lifecycle-manager-didEnterBackground")
        assert(BackgroundTask.lifecycleManagerDidBecomeActive.rawValue == "lifecycle-manager-didBecomeActive")
        assert(BackgroundTask.shortcutItem.rawValue == "shortcut-item")
        assert(BackgroundTask.handlePushAction.rawValue == "handle-push-action")
        assert(
            BackgroundTask.notificationManagerDidReceiveRegistrationToken
                .rawValue == "notificationManager-didReceiveRegistrationToken"
        )
        assert(BackgroundTask.zoneManagerPerformEvent.rawValue == "zone-manager-perform-event")
        assert(BackgroundTask.watchPushAction.rawValue == "watch-push-action")
        assert(BackgroundTask.webhookSendEphemeral.rawValue == "webhook-send-ephemeral")
        assert(BackgroundTask.webhookSend.rawValue == "webhook-send")
        assert(BackgroundTask.webhookInvoke.rawValue == "webhook-invoke")
        assert(BackgroundTask.manualLocationUpdate.rawValue == "manual-location-update")
        assert(BackgroundTask.signaledUpdateSensors.rawValue == "signaled-update-sensors")
        assert(BackgroundTask.connectApi.rawValue == "connect-api")
        assert(BackgroundTask.realmWrite.rawValue == "realm-write")
        assert(BackgroundTask.pushLocationRequest.rawValue == "push-location-request")
    }
}
