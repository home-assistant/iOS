@testable import HomeAssistant
import Testing

/// The browsers links can open in: each has a name, only Firefox offers private tabs, and the
/// built-in choices are always available.
struct OpenInBrowserTests {
    @Test func everyBrowserHasANameAndOnlyFirefoxHasPrivateTabs() {
        for browser in OpenInBrowser.allCases {
            #expect(!browser.title.isEmpty)
            #expect(browser.supportsPrivateTabs == (browser == .Firefox))
        }
        #expect(OpenInBrowser.Safari.isInstalled)
        #expect(OpenInBrowser.SafariInApp.isInstalled)
    }
}
