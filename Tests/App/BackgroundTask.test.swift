import Foundation
@testable import HomeAssistant
import PromiseKit
import Shared
import Testing

struct BackgroundTaskTests {
    @Test @MainActor func testApplicationRunnerDoesNotWaitForMainFromWorker() async {
        let wrapped = DispatchSemaphore(value: 0)
        let workerFinished = DispatchSemaphore(value: 0)
        let runner = ApplicationBackgroundTaskRunner(
            beginTask: { _, _ in .invalid },
            endTask: { _ in Issue.record("Invalid task must not be ended") },
            remainingTime: {
                Issue.record("A worker must not read UIKit's main-thread-only time hint")
                return 10
            }
        )
        DispatchQueue.global().async {
            let _: Promise<Void> = runner(withName: "worker-regression") { remaining in
                #expect(remaining == nil)
                wrapped.signal()
                return .value(())
            }
            workerFinished.signal()
        }
        // Deliberately occupy main while the worker acquires its lease. This bounded gate
        // reproduces the production main -> dataQueue -> main cycle without hanging the suite.
        #expect(wrapped.wait(timeout: .now() + 2) == .success)
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                _ = workerFinished.wait(timeout: .now() + 5)
                continuation.resume()
            }
        }
    }

    @Test @MainActor func testApplicationRunnerUsesRemainingTimeOnlyOnMain() {
        let cases: [(TimeInterval, TimeInterval?)] = [(20, 20), (100, nil)]
        for (time, expected) in cases {
            let runner = ApplicationBackgroundTaskRunner(
                beginTask: { _, _ in .invalid },
                endTask: { _ in Issue.record("Invalid task must not be ended") },
                remainingTime: { time }
            )
            let _: Promise<Void> = runner(withName: "main-hint") { remaining in
                #expect(remaining == expected)
                return .value(())
            }
        }
    }

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
