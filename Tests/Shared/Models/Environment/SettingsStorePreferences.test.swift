import Foundation
@testable import Shared
import XCTest

/// Round-trips and defaults of the preferences `SettingsStore` keeps in the app group defaults.
/// Every key a test touches is put back exactly as it was in `tearDown`.
final class SettingsStorePreferencesTests: XCTestCase {
    private static let touchedKeys = [
        "pushID",
        "page_zoom",
        "pinchToZoom",
        "flightGreetingsEnabled",
        "locationBasedServerSwitching",
        "lastActiveServerIdentifier",
        "lastActiveURLPath",
        "seenWhatsNewReleaseIDs",
        "seenTestFlightMessageIDs",
        "fullScreen",
        "webViewAlwaysBelowStatusBar",
        "enhancedWebSecurityEnabled",
        "refreshWebViewAfterInactive",
        "macNativeFeaturesOnly",
        "macNativeSidebarVisible",
        "hasSeenLiveActivityDisclosure",
        "migratedOptInLocalPush",
        "migratedShakeGestureToNone",
        "periodicUpdateInterval",
        "messagingEnabled",
        "crashesEnabled",
        "analyticsEnabled",
        "alertsEnabled",
        "updateCheckingEnabled",
        "updatesIncludeBetas",
        "locationVisibility",
        "menuItemTemplate-server",
        "menuItemTemplate",
        "locationUpdateOnZone",
        "locationUpdateOnBackgroundFetch",
        "locationUpdateOnSignificant",
        "locationUpdateOnNotification",
        "clearBadgeAutomatically",
        "forceCloseWarningEnabled",
        "notificationTapActionsEnabled",
        "widgetAuthenticityToken",
        "gesturesSettings",
        "receiveDebugNotifications",
        "webViewEmptyStateTimeout",
        "mediaTypesRequiringUserActionForPlayback",
    ]

    private var store: SettingsStore { Current.settingsStore }
    private var savedValues: [String: Any] = [:]
    private var previousServers: ServerManager!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        savedValues = [:]
        for key in Self.touchedKeys {
            if let value = store.prefs.object(forKey: key) {
                savedValues[key] = value
            }
            store.prefs.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in Self.touchedKeys {
            if let value = savedValues[key] {
                store.prefs.set(value, forKey: key)
            } else {
                store.prefs.removeObject(forKey: key)
            }
        }
        Current.servers = previousServers
        super.tearDown()
    }

    func testPushIDRoundTrips() {
        XCTAssertNil(store.pushID)
        store.pushID = "push-token"
        XCTAssertEqual(store.pushID, "push-token")
        store.pushID = nil
        XCTAssertNil(store.pushID)
    }

    func testPageZoomOptions() {
        XCTAssertEqual(SettingsStore.PageZoom.allCases.map(\.zoom), [50, 75, 85, 100, 115, 125, 150, 175, 200])
        XCTAssertEqual(SettingsStore.PageZoom.default.zoom, 100)
        XCTAssertNil(SettingsStore.PageZoom(preference: 33))
        XCTAssertEqual(SettingsStore.PageZoom(preference: 125)?.zoom, 125)

        XCTAssertEqual(SettingsStore.PageZoom(75).description, "75%")
        XCTAssertEqual(
            SettingsStore.PageZoom.default.description,
            L10n.SettingsDetails.General.PageZoom.default("100%")
        )
        XCTAssertEqual(SettingsStore.PageZoom(150).viewScaleValue, "1.50")
        XCTAssertEqual(SettingsStore.PageZoom(85).viewScaleValue, "0.85")
    }

    func testPageZoomPersistsAndFallsBackToDefault() {
        XCTAssertEqual(store.pageZoom, .default)

        let posted = expectation(forNotification: SettingsStore.webViewRelatedSettingDidChange, object: nil)
        store.pageZoom = SettingsStore.PageZoom(175)
        wait(for: [posted], timeout: 1)
        XCTAssertEqual(store.pageZoom.zoom, 175)

        // A stored value that is no longer offered falls back to the default.
        store.prefs.set(333, forKey: "page_zoom")
        XCTAssertEqual(store.pageZoom, .default)
    }

    func testMediaTypesRequiringUserActionForPlayback() {
        XCTAssertEqual(SettingsStore.MediaTypeRequiringUserActionForPlayback.audio.title, "Audio")
        XCTAssertEqual(SettingsStore.MediaTypeRequiringUserActionForPlayback.video.title, "Video")

        XCTAssertEqual(store.mediaTypesRequiringUserActionForPlayback, [.audio])
        store.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        XCTAssertEqual(store.mediaTypesRequiringUserActionForPlayback, [.audio, .video])
        XCTAssertEqual(
            store.prefs.stringArray(forKey: "mediaTypesRequiringUserActionForPlayback"),
            ["audio", "video"]
        )
        store.mediaTypesRequiringUserActionForPlayback = []
        XCTAssertEqual(store.mediaTypesRequiringUserActionForPlayback, [])
    }

    func testBooleanPreferencesThatDefaultToOff() {
        let keyPaths: [ReferenceWritableKeyPath<SettingsStore, Bool>] = [
            \.pinchToZoom,
            \.locationBasedServerSwitching,
            \.fullScreen,
            \.webViewAlwaysBelowStatusBar,
            \.enhancedWebSecurityEnabled,
            \.macNativeFeaturesOnly,
            \.hasSeenLiveActivityDisclosure,
            \.migratedOptInLocalPush,
            \.migratedShakeGestureToNone,
            \.forceCloseWarningEnabled,
            \.notificationTapActionsEnabled,
            \.receiveDebugNotifications,
        ]

        for keyPath in keyPaths {
            XCTAssertFalse(store[keyPath: keyPath], "\(keyPath)")
            store[keyPath: keyPath] = true
            XCTAssertTrue(store[keyPath: keyPath], "\(keyPath)")
            store[keyPath: keyPath] = false
            XCTAssertFalse(store[keyPath: keyPath], "\(keyPath)")
        }
    }

    func testBooleanPreferencesThatDefaultToOn() {
        let keyPaths: [ReferenceWritableKeyPath<SettingsStore, Bool>] = [
            \.flightGreetingsEnabled,
            \.refreshWebViewAfterInactive,
            \.macNativeSidebarVisible,
            \.clearBadgeAutomatically,
        ]

        for keyPath in keyPaths {
            XCTAssertTrue(store[keyPath: keyPath], "\(keyPath)")
            store[keyPath: keyPath] = false
            XCTAssertFalse(store[keyPath: keyPath], "\(keyPath)")
            store[keyPath: keyPath] = true
            XCTAssertTrue(store[keyPath: keyPath], "\(keyPath)")
        }
    }

    func testLastActiveServerAndPath() {
        XCTAssertNil(store.lastActiveServerIdentifier)
        XCTAssertNil(store.lastActiveURLPath)

        store.lastActiveServerIdentifier = "server-1"
        store.lastActiveURLPath = "/lovelace/0"

        XCTAssertEqual(store.lastActiveServerIdentifier, "server-1")
        XCTAssertEqual(store.lastActiveURLPath, "/lovelace/0")
    }

    func testWhatsNewAndTestFlightMessagesAreRememberedOnce() {
        XCTAssertFalse(store.hasSeenWhatsNew(releaseID: "2026.10"))
        store.markWhatsNewSeen(releaseID: "2026.10")
        store.markWhatsNewSeen(releaseID: "2026.9")
        store.markWhatsNewSeen(releaseID: "2026.10")
        XCTAssertTrue(store.hasSeenWhatsNew(releaseID: "2026.10"))
        XCTAssertTrue(store.hasSeenWhatsNew(releaseID: "2026.9"))
        XCTAssertFalse(store.hasSeenWhatsNew(releaseID: "2026.11"))
        XCTAssertEqual(store.prefs.stringArray(forKey: "seenWhatsNewReleaseIDs"), ["2026.10", "2026.9"])

        XCTAssertFalse(store.hasSeenTestFlightMessage(messageID: "beta-1"))
        store.markTestFlightMessageSeen(messageID: "beta-1")
        XCTAssertTrue(store.hasSeenTestFlightMessage(messageID: "beta-1"))
        XCTAssertFalse(store.hasSeenTestFlightMessage(messageID: "beta-2"))
    }

    func testPeriodicUpdateInterval() {
        XCTAssertEqual(store.periodicUpdateInterval, 300)

        store.periodicUpdateInterval = 60
        XCTAssertEqual(store.periodicUpdateInterval, 60)

        store.periodicUpdateInterval = nil
        XCTAssertNil(store.periodicUpdateInterval)
        XCTAssertEqual(store.prefs.double(forKey: "periodicUpdateInterval"), -1)
    }

    func testPrivacyDefaultsAndRoundTrip() {
        let defaults = store.privacy
        XCTAssertTrue(defaults.messaging)
        XCTAssertFalse(defaults.crashes)
        XCTAssertFalse(defaults.analytics)
        XCTAssertTrue(defaults.alerts)
        XCTAssertTrue(defaults.updates)
        XCTAssertTrue(defaults.updatesIncludeBetas)

        store.privacy = .init(
            messaging: false,
            crashes: true,
            analytics: true,
            alerts: false,
            updates: false,
            updatesIncludeBetas: false
        )

        let stored = store.privacy
        XCTAssertFalse(stored.messaging)
        XCTAssertTrue(stored.crashes)
        XCTAssertTrue(stored.analytics)
        XCTAssertFalse(stored.alerts)
        XCTAssertFalse(stored.updates)
        XCTAssertFalse(stored.updatesIncludeBetas)
        XCTAssertEqual(store.prefs.object(forKey: "crashesEnabled") as? Bool, true)
    }

    func testLocationVisibility() {
        typealias Visibility = SettingsStore.LocationVisibility

        XCTAssertTrue(Visibility.dock.isDockVisible)
        XCTAssertFalse(Visibility.dock.isStatusItemVisible)
        XCTAssertTrue(Visibility.dockAndMenuBar.isDockVisible)
        XCTAssertTrue(Visibility.dockAndMenuBar.isStatusItemVisible)
        XCTAssertFalse(Visibility.menuBar.isDockVisible)
        XCTAssertTrue(Visibility.menuBar.isStatusItemVisible)

        XCTAssertEqual(Visibility.dock.title, L10n.SettingsDetails.General.Visibility.Options.dock)
        XCTAssertEqual(Visibility.dockAndMenuBar.title, L10n.SettingsDetails.General.Visibility.Options.dockAndMenuBar)
        XCTAssertEqual(Visibility.menuBar.title, L10n.SettingsDetails.General.Visibility.Options.menuBar)

        XCTAssertEqual(store.locationVisibility, .dock)
        let posted = expectation(forNotification: SettingsStore.menuRelatedSettingDidChange, object: nil)
        store.locationVisibility = .menuBar
        wait(for: [posted], timeout: 1)
        XCTAssertEqual(store.locationVisibility, .menuBar)

        store.prefs.set("not-a-visibility", forKey: "locationVisibility")
        XCTAssertEqual(store.locationVisibility, .dock)
    }

    func testMenuItemTemplate() {
        let servers = FakeServerManager()
        Current.servers = servers
        XCTAssertNil(store.menuItemTemplate)

        let first = servers.addFake()
        let second = servers.addFake()

        // Nothing chosen yet: falls back to the first server with an empty template.
        XCTAssertEqual(store.menuItemTemplate?.server, first)
        XCTAssertEqual(store.menuItemTemplate?.template, "")

        store.menuItemTemplate = (second, "{{ states('sensor.temperature') }}")
        XCTAssertEqual(store.menuItemTemplate?.server, second)
        XCTAssertEqual(store.menuItemTemplate?.template, "{{ states('sensor.temperature') }}")

        // The chosen server was removed: falls back to the first one, keeping the template.
        servers.remove(identifier: second.identifier)
        XCTAssertEqual(store.menuItemTemplate?.server, first)
        XCTAssertEqual(store.menuItemTemplate?.template, "{{ states('sensor.temperature') }}")

        store.menuItemTemplate = nil
        XCTAssertNil(store.prefs.string(forKey: "menuItemTemplate"))
        XCTAssertNil(store.prefs.string(forKey: "menuItemTemplate-server"))
    }

    func testLocationSourcesDefaultToEnabledAndRoundTrip() {
        let defaults = store.locationSources
        XCTAssertTrue(defaults.zone)
        XCTAssertTrue(defaults.backgroundFetch)
        XCTAssertTrue(defaults.significantLocationChange)
        XCTAssertTrue(defaults.pushNotifications)

        let posted = expectation(forNotification: SettingsStore.locationRelatedSettingDidChange, object: nil)
        store.locationSources = .init(
            zone: false,
            backgroundFetch: true,
            significantLocationChange: false,
            pushNotifications: true
        )
        wait(for: [posted], timeout: 1)

        let stored = store.locationSources
        XCTAssertFalse(stored.zone)
        XCTAssertTrue(stored.backgroundFetch)
        XCTAssertFalse(stored.significantLocationChange)
        XCTAssertTrue(stored.pushNotifications)
    }

    func testWidgetAuthenticityTokenIsGeneratedOnceAndKept() {
        let token = store.widgetAuthenticityToken
        XCTAssertNotNil(UUID(uuidString: token))
        XCTAssertEqual(store.widgetAuthenticityToken, token)
        XCTAssertEqual(store.prefs.string(forKey: "widgetAuthenticityToken"), token)
    }

    func testGesturesFallBackToDefaultsAndRoundTrip() {
        XCTAssertEqual(store.gestures, .defaultGestures)

        var gestures = [AppGesture: HAGestureAction].defaultGestures
        gestures[.swipeLeft] = .nextServer
        gestures[.shake] = .assist
        store.gestures = gestures

        XCTAssertEqual(store.gestures, gestures)

        store.prefs.set(Data("not json".utf8), forKey: "gesturesSettings")
        XCTAssertEqual(store.gestures, .defaultGestures)
    }

    func testWebViewEmptyStateTimeout() {
        XCTAssertEqual(store.webViewEmptyStateTimeout, SettingsStore.defaultWebViewEmptyStateTimeout)
        store.webViewEmptyStateTimeout = 12
        XCTAssertEqual(store.webViewEmptyStateTimeout, 12)
    }
}
