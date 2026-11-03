@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

@Suite(.sharedState)
@MainActor
struct GeneralSettingsViewTests {
    /// Building the screen is what constructs the Enhanced Security row, which is the only place
    /// that setting is reachable from.
    @Test func buildsTheEnhancedWebSecurityRow() {
        _ = GeneralSettingsView().body
    }

    /// "Remember last page" lives here again, so search has to lead here for it, except on Catalyst,
    /// where the toggle is not shown.
    @Test func searchIndexesRememberLastPageWhereTheToggleShows() {
        let titles = GeneralSettingsView.settingsSearchEntries.map(\.title)
        #expect(titles.contains(L10n.SettingsDetails.General.Restoration.title) == !Current.isCatalyst)
    }

    /// Every switch on the screen writes its setting (the screen redraws after each); with a
    /// browser that has private tabs picked, its private tab switch shows too.
    @Test func switchesWriteTheirSettings() async throws {
        let store = Current.settingsStore
        let keys = GeneralSettingsUserDefaultKey.self
        let saved = (
            restoreLastURL: store.restoreLastURL,
            pinchToZoom: store.pinchToZoom,
            fullScreen: store.fullScreen,
            refresh: store.refreshWebViewAfterInactive,
            enhanced: store.enhancedWebSecurityEnabled,
            browser: prefs.object(forKey: keys.openInBrowser.rawValue),
            privateTab: prefs.object(forKey: keys.openInPrivateTab.rawValue),
            confirm: prefs.object(forKey: keys.confirmBeforeOpeningUrl.rawValue)
        )
        let previousCatalyst = Current.isCatalyst
        defer {
            store.restoreLastURL = saved.restoreLastURL
            store.pinchToZoom = saved.pinchToZoom
            store.fullScreen = saved.fullScreen
            store.refreshWebViewAfterInactive = saved.refresh
            store.enhancedWebSecurityEnabled = saved.enhanced
            prefs.set(saved.browser, forKey: keys.openInBrowser.rawValue)
            prefs.set(saved.privateTab, forKey: keys.openInPrivateTab.rawValue)
            prefs.set(saved.confirm, forKey: keys.confirmBeforeOpeningUrl.rawValue)
            Current.isCatalyst = previousCatalyst
        }
        Current.isCatalyst = false
        prefs.set(OpenInBrowser.Firefox.rawValue, forKey: keys.openInBrowser.rawValue)
        prefs.set(false, forKey: keys.openInPrivateTab.rawValue)

        let driver = await SwiftUIScreenDriver.show(GeneralSettingsView())
        defer { driver.close() }

        // Each switch redraws the whole screen, so they are looked up again before every flip.
        let pinch = store.pinchToZoom
        let count = driver.views(of: UISwitch.self, in: driver.topView).count
        #expect(count >= 6)
        for index in 0 ..< count {
            let switches = driver.views(of: UISwitch.self, in: driver.topView)
            guard index < switches.count else { break }
            switches[index].setOn(!switches[index].isOn, animated: false)
            switches[index].sendActions(for: .valueChanged)
            await driver.settle()
        }
        #expect(store.pinchToZoom != pinch)
        #expect(prefs.bool(forKey: keys.openInPrivateTab.rawValue))
    }
}
