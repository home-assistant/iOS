@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit
import UserNotifications
import XCGLogger

@MainActor
@Suite(.sharedState)
struct DebugViewTests {
    /// Every row of the debugging screen is built inline in its body, so nothing else in the suite
    /// runs that code: a row that stopped resolving — a missing icon, a destination that no longer
    /// compiles into the list — would only show up when someone opened the screen by hand.
    /// Building the body is the assertion; it traps if a row cannot be constructed.
    @Test func theScreenBuildsItsRows() {
        _ = DebugView().body
    }

    @Test func theDeveloperSectionBuildsItsRows() {
        _ = DebugView().developerSection
    }

    @Test func simulatingARestoreMakesTheRestoredDevicePromptShow() {
        let prefs = Current.settingsStore.prefs
        let keys = [
            SettingsStore.integrationDeviceIDKey,
            SettingsStore.integrationDeviceIDOwnerKey,
            SettingsStore.registrationRecordsKey,
            RegistrationOwnership.earlierRegistrationsAdoptedKey,
        ]
        let previousValues = keys.map { prefs.object(forKey: $0) }
        let previousServers = Current.servers
        let previousVendorID = Current.device.identifierForVendor
        let previousIsCatalyst = Current.isCatalyst
        defer {
            Current.servers = previousServers
            Current.device.identifierForVendor = previousVendorID
            Current.isCatalyst = previousIsCatalyst
            for (key, value) in zip(keys, previousValues) {
                prefs.set(value, forKey: key)
            }
        }

        let servers = FakeServerManager(initial: 0)
        Current.servers = servers
        Current.device.identifierForVendor = { "this-device" }
        Current.isCatalyst = false
        keys.forEach(prefs.removeObject(forKey:))
        prefs.set("this-device", forKey: SettingsStore.integrationDeviceIDKey)
        let server = servers.addFake()
        #expect(!LaunchMessagesState.messagesToShow().map(\.id).contains("restoredRegistrations"))

        DebugView().simulateRestoredDevice()

        guard case let .restoredRegistrations(restored)? = LaunchMessagesState.messagesToShow().first else {
            Issue.record("Expected the restored device prompt to come first")
            return
        }
        #expect(restored == [server])
    }

    @Test func theLocalPushStateToggleReadsAndWritesThePreference() {
        let original = Current.settingsStore.notifyOnLocalPushStateChanges
        defer { Current.settingsStore.notifyOnLocalPushStateChanges = original }

        let binding = DebugView.notifyOnLocalPushStateChangesBinding
        binding.wrappedValue = true
        #expect(Current.settingsStore.notifyOnLocalPushStateChanges)
        #expect(binding.wrappedValue)
        binding.wrappedValue = false
        #expect(!binding.wrappedValue)
    }

    @Test func theRegionEnterFuzzDistancePickerReadsAndWritesThePreference() {
        let original = Current.settingsStore.regionEnterMaximumFuzzDistance
        defer { Current.settingsStore.regionEnterMaximumFuzzDistance = original }

        let binding = DebugView.regionEnterMaximumFuzzDistanceBinding
        binding.wrappedValue = 500
        #expect(Current.settingsStore.regionEnterMaximumFuzzDistance == 500)
        #expect(binding.wrappedValue == 500)

        #expect(DebugView.regionEnterMaximumFuzzDistanceOptions.contains(
            SettingsStore.defaultRegionEnterMaximumFuzzDistance
        ))
        _ = DebugView.regionEnterMaximumFuzzDistanceRow(250)
        _ = DebugView.regionEnterMaximumFuzzDistanceRows()
    }

    // MARK: - Driving the screen

    /// Settings the developer rows write, saved before a test drives them and put back after.
    private struct SavedDeveloperSettings {
        let mediaTypes = Current.settingsStore.mediaTypesRequiringUserActionForPlayback
        let carPlay = Current.settingsStore.carPlayAssistDebugSettings
        let receiveDebugNotifications = Current.settingsStore.receiveDebugNotifications
        let notifyOnLocalPush = Current.settingsStore.notifyOnLocalPushStateChanges
        let belowStatusBar = Current.settingsStore.webViewAlwaysBelowStatusBar
        let translationKeys = prefs.object(forKey: "showTranslationKeys")
        let annoyingNotifications = prefs.object(forKey: XCGLogger.shouldNotifyUserDefaultsKey)

        func restore() {
            Current.settingsStore.mediaTypesRequiringUserActionForPlayback = mediaTypes
            Current.settingsStore.carPlayAssistDebugSettings = carPlay
            Current.settingsStore.receiveDebugNotifications = receiveDebugNotifications
            Current.settingsStore.notifyOnLocalPushStateChanges = notifyOnLocalPush
            Current.settingsStore.webViewAlwaysBelowStatusBar = belowStatusBar
            prefs.set(translationKeys, forKey: "showTranslationKeys")
            prefs.set(annoyingNotifications, forKey: XCGLogger.shouldNotifyUserDefaultsKey)
        }
    }

    /// Ten taps on the logo swap it for the developer section.
    private func unlockDeveloperSection(_ driver: SwiftUIScreenDriver) async throws -> Int {
        let logoSection = driver.sectionCount - 1
        try #require(logoSection > 0)
        for _ in 0 ..< 10 {
            await driver.tapRow(IndexPath(item: 0, section: logoSection))
        }
        await #expect(driver.waitUntil { driver.rowCount(inSection: logoSection) > 10 })
        return logoSection
    }

    @Test func tenLogoTapsRevealTheDeveloperSection() async throws {
        let driver = await SwiftUIScreenDriver.show(DebugView())
        defer { driver.close() }
        let section = try await unlockDeveloperSection(driver)
        #expect(driver.rowCount(inSection: section) > 10)
    }

    /// The media playback screen toggles each media type in and out of the stored set.
    @Test func theMediaPlaybackScreenTogglesEachType() async throws {
        let saved = SavedDeveloperSettings()
        defer { saved.restore() }
        Current.settingsStore.mediaTypesRequiringUserActionForPlayback = []

        let driver = await SwiftUIScreenDriver.show(DebugView())
        defer { driver.close() }
        let section = try await unlockDeveloperSection(driver)

        try await #require(driver.push(IndexPath(item: 1, section: section)))
        let rows = driver.rows
        #expect(rows.count == SettingsStore.MediaTypeRequiringUserActionForPlayback.allCases.count)
        for row in rows {
            await driver.tapRow(row)
        }
        await #expect(driver.waitUntil {
            Current.settingsStore.mediaTypesRequiringUserActionForPlayback.count == rows.count
        })
        for row in rows {
            await driver.tapRow(row)
        }
        await #expect(driver.waitUntil {
            Current.settingsStore.mediaTypesRequiringUserActionForPlayback.isEmpty
        })
    }

    /// The CarPlay debug screen writes every switch through to the stored settings.
    @Test func theCarPlayDebugScreenStoresItsSwitches() async throws {
        let saved = SavedDeveloperSettings()
        defer { saved.restore() }
        Current.settingsStore.carPlayAssistDebugSettings = .default

        let driver = await SwiftUIScreenDriver.show(DebugView())
        defer { driver.close() }
        let section = try await unlockDeveloperSection(driver)

        try await #require(driver.push(IndexPath(item: 5, section: section)))
        #expect(driver.sectionCount == 4)
        await driver.toggleSwitches()
        await #expect(driver.waitUntil { Current.settingsStore.carPlayAssistDebugSettings != .default })
        // The reset row only asks for confirmation.
        await driver.tapRow(IndexPath(item: 0, section: 3))
        #expect(Current.settingsStore.carPlayAssistDebugSettings != .default)
    }

    /// The developer buttons and switches that act right away: syncing the watch, debug strings,
    /// the sample notifications and the switches, plus the rows that only raise a confirmation.
    @Test func theDeveloperRowsActOnTheirSettings() async throws {
        let saved = SavedDeveloperSettings()
        defer { saved.restore() }
        prefs.set(false, forKey: "showTranslationKeys")
        let previousCatalyst = Current.isCatalyst
        Current.isCatalyst = false
        defer { Current.isCatalyst = previousCatalyst }

        let driver = await SwiftUIScreenDriver.show(DebugView())
        defer { driver.close() }
        let section = try await unlockDeveloperSection(driver)

        // Syncing the watch context without a paired watch finishes without an error.
        await driver.tapRow(IndexPath(item: 6, section: section))
        await driver.tapRow(IndexPath(item: 7, section: section))
        #expect(prefs.bool(forKey: "showTranslationKeys"))
        await driver.tapRow(IndexPath(item: 7, section: section))
        #expect(!prefs.bool(forKey: "showTranslationKeys"))

        await driver.tapRow(IndexPath(item: 8, section: section))
        await driver.tapRow(IndexPath(item: 9, section: section))
        let center = UNUserNotificationCenter.current()
        let sampleIDs = ["cameraContentExtension", "mapContentExtension"]
        center.removePendingNotificationRequests(withIdentifiers: sampleIDs)
        center.removeDeliveredNotifications(withIdentifiers: sampleIDs)

        let receiveDebug = Current.settingsStore.receiveDebugNotifications
        await driver.toggleSwitches()
        #expect(Current.settingsStore.receiveDebugNotifications != receiveDebug)
        await driver.toggleSwitches()
        #expect(Current.settingsStore.receiveDebugNotifications == receiveDebug)

        // Clearing tags, deleting credentials and simulating a restore each only raise a prompt.
        for item in 10 ... 12 {
            await driver.tapRow(IndexPath(item: item, section: section))
        }
    }

    /// Exporting logs zips them and hands the archive to a share sheet, which deletes it once it
    /// closes. The share sheet is recorded on the window's root instead of being presented.
    @Test func exportingLogsSharesAnArchiveAndDeletesItAfterwards() async throws {
        let previousCatalyst = Current.isCatalyst
        Current.isCatalyst = false
        defer { Current.isCatalyst = previousCatalyst }

        let screen = await RecordingScreen.show(NavigationStack { DebugView() })
        defer { screen.close() }

        let pressed = await screen.pressBarButton(L10n.Settings.Developer.ExportLogFiles.title)
        try #require(pressed, "No export button among \(screen.barButtons.map { $0.title ?? "-" })")
        await #expect(screen.waitUntil { !screen.presented(UIActivityViewController.self).isEmpty })
        let activity = screen.presented(UIActivityViewController.self).first
        let shareSheet = try #require(activity)
        shareSheet.completionWithItemsHandler?(nil, false, nil, nil)
        await screen.settle()
        // A second close finds the archive already gone, which is only logged.
        shareSheet.completionWithItemsHandler?(nil, false, nil, nil)
        await screen.settle()
    }

    /// On the Mac, exporting logs opens the archive in Finder instead of sharing it.
    @Test func exportingLogsOnTheMacOpensTheArchive() async throws {
        let previousCatalyst = Current.isCatalyst
        let previousOpener = URLOpener.shared
        let opener = MockURLOpener()
        Current.isCatalyst = true
        URLOpener.shared = opener
        defer {
            Current.isCatalyst = previousCatalyst
            URLOpener.shared = previousOpener
        }

        let screen = await RecordingScreen.show(NavigationStack { DebugView() })
        defer { screen.close() }

        let pressed = await screen.pressBarButton(L10n.Settings.Developer.ShowLogFiles.title)
        try #require(pressed, "No show-logs button among \(screen.barButtons.map { $0.title ?? "-" })")
        await #expect(screen.waitUntil { !opener.openedURLs.isEmpty })
        #expect(screen.presented(UIActivityViewController.self).isEmpty)
        for opened in opener.openedURLs {
            try? FileManager.default.removeItem(at: opened.url)
        }
    }

    /// The critical rows (cached entities, web cache, reset) each only ask for confirmation first.
    @Test func theCriticalRowsOnlyAskForConfirmation() async throws {
        try await SettingsTestDatabase.with({ db in
            try HAAppEntity(
                id: "server-light.kitchen",
                entityId: "light.kitchen",
                serverId: "server",
                domain: "light",
                name: "Kitchen",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db)
        }) { database in
            let driver = await SwiftUIScreenDriver.show(DebugView())
            defer { driver.close() }
            let critical = driver.sectionCount - 2
            try #require(driver.rowCount(inSection: critical) == 3)

            for item in 0 ..< 3 {
                await driver.tapRow(IndexPath(item: item, section: critical))
            }
            let entities = try await database.read { db in try HAAppEntity.fetchCount(db) }
            #expect(entities == 1)
        }
    }
}
