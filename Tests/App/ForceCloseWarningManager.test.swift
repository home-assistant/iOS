@testable import HomeAssistant
@testable import Shared
import Testing
import UserNotifications

struct ForceCloseWarningManagerTests {
    @Test func settingsStoreDefaultsToDisabled() {
        Current.settingsStore.prefs.removeObject(forKey: "forceCloseWarningEnabled")
        #expect(Current.settingsStore.forceCloseWarningEnabled == false)
    }

    @Test func settingsStorePersistsToggle() {
        Current.settingsStore.forceCloseWarningEnabled = true
        #expect(Current.settingsStore.forceCloseWarningEnabled == true)
        Current.settingsStore.forceCloseWarningEnabled = false
        #expect(Current.settingsStore.forceCloseWarningEnabled == false)
    }

    @Test func contentUsesGivenTitleAndBody() {
        let content = ForceCloseWarningManager.makeContent(title: "t", body: "b")
        #expect(content.title == "t")
        #expect(content.body == "b")
    }

    @Test func requestUsesStableIdentifierAndDelay() {
        let content = ForceCloseWarningManager.makeContent(title: "t", body: "b")
        let request = ForceCloseWarningManager.makeRequest(content: content, delay: 10)
        #expect(request.identifier == ForceCloseWarningManager.notificationIdentifier)
        let trigger = try? #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger?.timeInterval == 10)
        #expect(trigger?.repeats == false)
    }

    @Test func immediateRequestHasNoTriggerAndSameIdentifier() {
        let content = ForceCloseWarningManager.makeContent(title: "t", body: "b")
        let request = ForceCloseWarningManager.makeImmediateRequest(content: content)
        #expect(request.identifier == ForceCloseWarningManager.notificationIdentifier)
        #expect(request.trigger == nil)
    }
}
