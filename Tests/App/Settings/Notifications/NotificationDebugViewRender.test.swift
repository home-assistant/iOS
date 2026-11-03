import Foundation
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Shared state: reads the push ID from preferences, flips the location-notification preferences
/// and asks the rate-limit service through a process-wide HTTP stub.
@Suite(.sharedState)
@MainActor
struct NotificationDebugViewRenderTests {
    private static let rateLimitJSON = """
    {"target": "push-id", "rateLimits": {"attempts": 1, "successful": 1, "errors": 0, "total": 1,
     "maximum": 500, "remaining": 499, "resetsAt": "2026-10-31T00:00:00.000Z"}}
    """

    @Test func showsTheRateLimitAndOpensItsScreens() async throws {
        let previousPushID = Current.settingsStore.pushID
        Current.settingsStore.pushID = "push-id"
        let descriptor = stub(
            condition: { $0.url?.path == "/api/checkRateLimits" },
            response: { _ in .init(data: Data(Self.rateLimitJSON.utf8), statusCode: 200, headers: nil) }
        )
        let keys = [
            "enterNotifications", "exitNotifications", "beaconEnterNotifications", "beaconExitNotifications",
            "significantLocationChangeNotifications", "backgroundFetchLocationChangeNotifications",
            "pushLocationRequestNotifications", "urlSchemeLocationRequestNotifications",
            "xCallbackURLLocationRequestNotifications",
        ]
        let previousPrefs = keys.map { prefs.object(forKey: $0) }
        defer {
            HTTPStubs.removeStub(descriptor)
            Current.settingsStore.pushID = previousPushID
            for (key, value) in zip(keys, previousPrefs) {
                prefs.set(value, forKey: key)
            }
        }

        let viewModel = NotificationDebugViewModel()
        #expect(viewModel.pushID == "push-id")
        #expect(viewModel.pushIDDisplay == "push-id")

        let driver = await SwiftUIScreenDriver.show(NotificationDebugView())
        defer { driver.close() }
        #expect(driver.rowCount(inSection: 0) == 4)

        await #expect(driver.push(IndexPath(item: 0, section: 0)))
        await #expect(driver.waitUntil { driver.rowCount(inSection: 0) == 5 })
        await driver.pop()

        await #expect(driver.push(IndexPath(item: 1, section: 0)))
        #expect(driver.rowCount(inSection: 0) == keys.count)
        let before = prefs.bool(forKey: keys[0])
        await driver.toggleSwitches()
        #expect(prefs.bool(forKey: keys[0]) != before)
        await driver.pop()

        // The push ID row shares it.
        await driver.tapRow(IndexPath(item: 2, section: 0))
        if await driver.waitUntil(timeout: 5, { driver.presented != nil }) {
            await driver.dismissPresented()
        }
    }

    @Test func withoutAPushIDThereIsNothingToShare() async {
        let previousPushID = Current.settingsStore.pushID
        Current.settingsStore.pushID = nil
        defer { Current.settingsStore.pushID = previousPushID }

        let viewModel = NotificationDebugViewModel()
        #expect(viewModel.pushID == nil)
        #expect(viewModel.pushIDDisplay == L10n.SettingsDetails.Notifications.PushIdSection.notRegistered)

        let driver = await SwiftUIScreenDriver.show(NotificationDebugView())
        defer { driver.close() }
        await driver.tapRow(IndexPath(item: 2, section: 0))
        #expect(driver.presented == nil)
    }
}
