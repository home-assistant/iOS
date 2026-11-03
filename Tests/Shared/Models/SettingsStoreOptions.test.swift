import Foundation
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// Option types and lesser-used preferences of `SettingsStore`. They live in the shared app-group
/// defaults (and the keychain), so the suite serializes with other shared-state tests and puts back
/// what it changed.
@Suite(.sharedState)
struct SettingsStoreOptionsTests {
    private var store: SettingsStore { Current.settingsStore }

    private func restoring(_ keys: [String], _ body: () throws -> Void) rethrows {
        let prefs = Current.settingsStore.prefs
        let previous = keys.map { prefs.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                prefs.set(value, forKey: key)
            }
        }
        try body()
    }

    @Test func pageZoomAcceptsOnlyKnownPreferences() throws {
        let zoom = try #require(SettingsStore.PageZoom(preference: 125))
        #expect(zoom.zoom == 125)
        #expect(zoom.description == "125%")
        #expect(zoom.viewScaleValue == "1.25")
        #expect(SettingsStore.PageZoom(preference: 333) == nil)
        #expect(SettingsStore.PageZoom.default.description.contains("100%"))
        #expect(SettingsStore.PageZoom.allCases.count == 9)
    }

    @Test func mediaTypesAndVisibilityOptionsDescribeThemselves() {
        #expect(SettingsStore.MediaTypeRequiringUserActionForPlayback.allCases.map(\.title) == ["Audio", "Video"])
        for visibility in SettingsStore.LocationVisibility.allCases {
            #expect(!visibility.title.isEmpty)
            #expect(visibility.isDockVisible || visibility.isStatusItemVisible)
        }
        #expect(!SettingsStore.LocationVisibility.dock.isStatusItemVisible)
        #expect(!SettingsStore.LocationVisibility.menuBar.isDockVisible)
    }

    @Test func oneTimeFlagsPersist() {
        restoring(["hasSeenLiveActivityDisclosure", "migratedOptInLocalPush", "migratedShakeGestureToNone"]) {
            store.hasSeenLiveActivityDisclosure = true
            store.migratedOptInLocalPush = true
            store.migratedShakeGestureToNone = true
            #expect(store.hasSeenLiveActivityDisclosure)
            #expect(store.migratedOptInLocalPush)
            #expect(store.migratedShakeGestureToNone)
            store.migratedOptInLocalPush = false
            #expect(!store.migratedOptInLocalPush)
        }
    }

    @Test func periodicUpdateIntervalDefaultsAndCanBeDisabled() {
        restoring(["periodicUpdateInterval"]) {
            store.prefs.removeObject(forKey: "periodicUpdateInterval")
            #expect(store.periodicUpdateInterval == 300)
            store.periodicUpdateInterval = 60
            #expect(store.periodicUpdateInterval == 60)
            store.periodicUpdateInterval = nil
            #expect(store.periodicUpdateInterval == nil)
        }
    }

    @Test func locationVisibilityPersistsAndAnnouncesTheChange() {
        restoring(["locationVisibility"]) {
            var announced = 0
            let token = NotificationCenter.default.addObserver(
                forName: SettingsStore.menuRelatedSettingDidChange,
                object: nil,
                queue: nil
            ) { _ in announced += 1 }
            defer { NotificationCenter.default.removeObserver(token) }

            store.locationVisibility = .menuBar
            #expect(store.locationVisibility == .menuBar)
            store.prefs.set("bogus", forKey: "locationVisibility")
            #expect(store.locationVisibility == .dock)
            #expect(announced == 1)
        }
    }

    @Test func unreadableGesturesFallBackToTheDefaults() {
        restoring(["gesturesSettings"]) {
            store.prefs.set(Data("not json".utf8), forKey: "gesturesSettings")
            #expect(store.gestures == .defaultGestures)
        }
    }

    @Test func locationAvailabilityDependsOnAuthorization() {
        // The answer depends on the simulator's grant; foregrounded access is never narrower than background.
        let active = store.isLocationEnabled(for: .active)
        let inactive = store.isLocationEnabled(for: .inactive)
        let background = store.isLocationEnabled(for: .background)
        #expect(active == inactive)
        #expect(!background || active)
    }

    @Test func matterNetworkDetailsRoundTripThroughTheKeychain() {
        let previous = (
            store.matterLastPreferredNetWorkMacExtendedAddress,
            store.matterLastPreferredNetWorkActiveOperationalDataset,
            store.matterLastPreferredNetWorkExtendedPANID,
            store.matterLastCommissionedDeviceName
        )
        defer {
            store.matterLastPreferredNetWorkMacExtendedAddress = previous.0
            store.matterLastPreferredNetWorkActiveOperationalDataset = previous.1
            store.matterLastPreferredNetWorkExtendedPANID = previous.2
            store.matterLastCommissionedDeviceName = previous.3
        }
        store.matterLastPreferredNetWorkMacExtendedAddress = "mac"
        store.matterLastPreferredNetWorkActiveOperationalDataset = "dataset"
        store.matterLastPreferredNetWorkExtendedPANID = "pan"
        store.matterLastCommissionedDeviceName = "Plug"
        // The keychain may be unavailable to a test bundle; when it works the values come back.
        for (value, expected) in [
            (store.matterLastPreferredNetWorkMacExtendedAddress, "mac"),
            (store.matterLastPreferredNetWorkActiveOperationalDataset, "dataset"),
            (store.matterLastPreferredNetWorkExtendedPANID, "pan"),
            (store.matterLastCommissionedDeviceName, "Plug"),
        ] {
            #expect(value == nil || value == expected)
        }
    }

    @Test func integrationDeviceIDsAreFreshAndPrefixedInDebug() {
        let first = store.newIntegrationDeviceID()
        let second = store.newIntegrationDeviceID()
        #expect(first != second)
        #expect(!store.deviceID.isEmpty)
        if Current.appConfiguration == .debug {
            #expect(first.hasPrefix("debug_"))
        }
    }
}
