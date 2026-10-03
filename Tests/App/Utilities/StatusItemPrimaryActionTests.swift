import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

// Serialized: the tests swap `Current.servers`, `URLOpener.shared` and the browser preference.
@Suite(.serialized)
struct StatusItemPrimaryActionTests {
    private func withEnvironment(
        browserPreference: Bool,
        serverCount: Int,
        _ body: (MockURLOpener) -> Void
    ) {
        let previousServers = Current.servers
        let previousOpener = URLOpener.shared
        let previousPreference = Current.settingsStore.macNativeFeaturesOnly
        defer {
            Current.servers = previousServers
            URLOpener.shared = previousOpener
            Current.settingsStore.macNativeFeaturesOnly = previousPreference
        }

        let opener = MockURLOpener()
        Current.servers = FakeServerManager(initial: serverCount)
        URLOpener.shared = opener
        Current.settingsStore.macNativeFeaturesOnly = browserPreference
        body(opener)
    }

    @Test func fallsThroughWhenTheAppShowsItsOwnWindow() {
        withEnvironment(browserPreference: false, serverCount: 1) { opener in
            #expect(StatusItemPrimaryAction.openInBrowserIfNeeded() == false)
            #expect(opener.openedURLs.isEmpty)
        }
    }

    @Test func opensTheServerInTheBrowserWhenThePreferenceIsOn() {
        withEnvironment(browserPreference: true, serverCount: 1) { opener in
            #expect(StatusItemPrimaryAction.openInBrowserIfNeeded())
            #expect(opener.openedURLs.map(\.url) == [URL(string: "http://homeassistant.local:8123")!])
        }
    }

    @Test func fallsThroughWithoutAServerToOpen() {
        withEnvironment(browserPreference: true, serverCount: 0) { opener in
            #expect(StatusItemPrimaryAction.openInBrowserIfNeeded() == false)
            #expect(opener.openedURLs.isEmpty)
        }
    }
}
