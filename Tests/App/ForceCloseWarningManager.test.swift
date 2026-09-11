@testable import HomeAssistant
@testable import Shared
import Testing

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

    @Test func immediateRequestHasNoTriggerAndSameIdentifier() {
        let content = ForceCloseWarningManager.makeContent(title: "t", body: "b")
        let request = ForceCloseWarningManager.makeImmediateRequest(content: content)
        #expect(request.identifier == ForceCloseWarningManager.notificationIdentifier)
        #expect(request.trigger == nil)
    }
}
