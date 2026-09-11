@testable import HomeAssistant
@testable import Shared
import CoreLocation
import Testing
import UserNotifications

// Serialized: the tests mutate process-wide app-group defaults and shared `Current` dependencies.
@Suite(.serialized)
struct ForceCloseWarningManagerTests {
    @Test func settingsStoreDefaultsToDisabled() {
        withForceCloseWorld {
            Current.settingsStore.prefs.removeObject(forKey: "forceCloseWarningEnabled")
            #expect(Current.settingsStore.forceCloseWarningEnabled == false)
        }
    }

    @Test func settingsStorePersistsToggle() {
        withForceCloseWorld {
            Current.settingsStore.forceCloseWarningEnabled = true
            #expect(Current.settingsStore.forceCloseWarningEnabled == true)
            Current.settingsStore.forceCloseWarningEnabled = false
            #expect(Current.settingsStore.forceCloseWarningEnabled == false)
        }
    }

    @Test func contentUsesGivenTitleAndBody() {
        let content = ForceCloseWarningManager.makeContent(title: "t", body: "b")
        #expect(content.title == "t")
        #expect(content.body == "b")
    }

    @Test func immediateRequestHasNoTriggerAndSameIdentifier() {
        let content = ForceCloseWarningManager.makeContent(title: "t", body: "b")
        let request = ForceCloseWarningManager.makeImmediateRequest(content: content)
        #expect(request.identifier == ForceCloseWarningManager.notificationIdentifier)
        #expect(request.trigger == nil)
    }

    @Test func disabledOnCatalyst() {
        withForceCloseWorld(isCatalyst: true, toggle: true, permission: .authorizedAlways) {
            #expect(ForceCloseWarningManager.isEnabled == false)
        }
    }

    @Test func disabledWhenToggledOff() {
        withForceCloseWorld(toggle: false, permission: .authorizedAlways) {
            #expect(ForceCloseWarningManager.isEnabled == false)
        }
    }

    @Test func disabledWithoutAlwaysLocation() {
        withForceCloseWorld(toggle: true, permission: .authorizedWhenInUse) {
            #expect(ForceCloseWarningManager.isEnabled == false)
        }
    }

    @Test func enabledWithToggleAndAlwaysLocation() {
        withForceCloseWorld(toggle: true, permission: .authorizedAlways) {
            #expect(ForceCloseWarningManager.isEnabled == true)
        }
    }

    @Test func postsImmediatelyWhenEnabled() {
        withForceCloseWorld(toggle: true, permission: .authorizedAlways) {
            var posted: [UNNotificationRequest] = []
            ForceCloseWarningManager(addRequest: { posted.append($0) }).postImmediateWarning()
            #expect(posted.count == 1)
            #expect(posted.first?.identifier == ForceCloseWarningManager.notificationIdentifier)
            #expect(posted.first?.trigger == nil)
        }
    }

    @Test func doesNotPostWhenDisabled() {
        withForceCloseWorld(toggle: false, permission: .authorizedAlways) {
            var posted: [UNNotificationRequest] = []
            ForceCloseWarningManager(addRequest: { posted.append($0) }).postImmediateWarning()
            #expect(posted.isEmpty)
        }
    }

    @Test func doesNotPostWithoutAlwaysLocation() {
        withForceCloseWorld(toggle: true, permission: .denied) {
            var posted: [UNNotificationRequest] = []
            ForceCloseWarningManager(addRequest: { posted.append($0) }).postImmediateWarning()
            #expect(posted.isEmpty)
        }
    }

    /// Saves every shared value these tests touch and restores it after, so they never
    /// leak state into each other or into unrelated suites sharing the process.
    private func withForceCloseWorld(
        isCatalyst: Bool = false,
        toggle: Bool = false,
        permission: CLAuthorizationStatus = .notDetermined,
        _ body: () throws -> Void
    ) rethrows {
        let previousToggle = Current.settingsStore.forceCloseWarningEnabled
        let previousCatalyst = Current.isCatalyst
        let previousPermission = Current.location.permissionStatus
        defer {
            Current.settingsStore.forceCloseWarningEnabled = previousToggle
            Current.isCatalyst = previousCatalyst
            Current.location.permissionStatus = previousPermission
        }
        Current.isCatalyst = isCatalyst
        Current.settingsStore.forceCloseWarningEnabled = toggle
        Current.location.permissionStatus = { permission }
        try body()
    }
}
