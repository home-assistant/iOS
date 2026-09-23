import CoreLocation
@testable import HomeAssistant
@testable import Shared
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

// `AppDelegate.applicationWillTerminate` is the only caller of `ForceCloseWarningManager.postImmediateWarning`,
// and it is the wiring this feature ships to production. Stub the manager through `Current` and assert the
// delegate hands off when iOS terminates the app.
@Suite(.serialized)
struct AppDelegateForceCloseTerminationTests {
    @Test func applicationWillTerminateHandsOffToTheWarningManager() {
        withForceCloseWorld(toggle: true, permission: .authorizedAlways) {
            let previousManager = Current.forceCloseWarningManager
            var posted: [UNNotificationRequest] = []
            Current.forceCloseWarningManager = ForceCloseWarningManager(addRequest: { posted.append($0) })
            defer { Current.forceCloseWarningManager = previousManager }

            AppDelegate().applicationWillTerminate(UIApplication.shared)

            #expect(posted.count == 1)
            #expect(posted.first?.identifier == ForceCloseWarningManager.notificationIdentifier)
        }
    }

    @Test func applicationWillTerminateForgetsTheLastPage() {
        withForceCloseWorld(toggle: true, permission: .authorizedAlways) {
            withLastPage(server: "server-1", path: "/config/integrations/integration/hue") {
                AppDelegate().applicationWillTerminate(UIApplication.shared)

                #expect(Current.settingsStore.lastActiveURLPath == nil)
                #expect(Current.settingsStore.lastActiveServerIdentifier == "server-1")
            }
        }
    }

    @Test func applicationWillTerminateForgetsTheLastPageEvenWhenTheWarningIsDisabled() {
        withForceCloseWorld(toggle: false, permission: .denied) {
            withLastPage(server: "server-1", path: "/config/integrations/integration/hue") {
                AppDelegate().applicationWillTerminate(UIApplication.shared)

                #expect(Current.settingsStore.lastActiveURLPath == nil)
                #expect(Current.settingsStore.lastActiveServerIdentifier == "server-1")
            }
        }
    }

    @Test func applicationWillTerminateKeepsTheLastPageOnCatalyst() {
        withForceCloseWorld(isCatalyst: true) {
            withLastPage(server: "server-1", path: "/config/integrations/integration/hue") {
                AppDelegate().applicationWillTerminate(UIApplication.shared)

                #expect(Current.settingsStore.lastActiveURLPath == "/config/integrations/integration/hue")
                #expect(Current.settingsStore.lastActiveServerIdentifier == "server-1")
            }
        }
    }
}

private func withLastPage(server: String, path: String, _ body: () throws -> Void) rethrows {
    let previousServer = Current.settingsStore.lastActiveServerIdentifier
    let previousPath = Current.settingsStore.lastActiveURLPath
    defer {
        Current.settingsStore.lastActiveServerIdentifier = previousServer
        Current.settingsStore.lastActiveURLPath = previousPath
    }
    Current.settingsStore.lastActiveServerIdentifier = server
    Current.settingsStore.lastActiveURLPath = path
    try body()
}
