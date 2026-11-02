@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Shared state: playing and importing touch the app container's `Library/Sounds` folder.
@Suite(.sharedState)
@MainActor
struct NotificationSoundsViewRenderTests {
    private func makeDriver() async -> SwiftUIScreenDriver {
        await SwiftUIScreenDriver.show(
            NotificationSoundsView()
                .environmentObject(ViewControllerProvider())
        )
    }

    @Test func rendersEachCategory() async {
        let driver = await makeDriver()
        defer { driver.close() }
        // The segmented picker, then the imported sounds followed by the two import buttons.
        #expect(driver.sectionCount == 2)
        #expect(driver.rowCount(inSection: 1) >= 2)

        // Bundled: one row per sound shipped with the app, and no import buttons.
        await driver.selectSegment(1)
        await #expect(driver.waitUntil { driver.rowCount(inSection: 1) > 50 })
        // Tapping a bundled sound plays it.
        await driver.tapRow(IndexPath(item: 0, section: 1))

        // System: the imported system sounds followed by the import button.
        await driver.selectSegment(2)
        await #expect(driver.waitUntil { driver.rowCount(inSection: 1) < 50 })
    }

    @Test func importingFromFileSharingShowsTheResult() async throws {
        try await LibrarySoundsFolder.preserved {
            let driver = await makeDriver()
            defer { driver.close() }

            // "Import from file sharing" is the last row of the imported section.
            await driver.tapRow(IndexPath(item: driver.rowCount(inSection: 1) - 1, section: 1))
            // The import finishes with an alert reporting how many sounds were copied.
            await #expect(driver.waitUntil(timeout: 30) { driver.alert != nil })
            await driver.tapAlertButton()
        }
    }

    /// The imported system sounds are undone by restoring the sounds folder as it was.
    @Test func importingSystemSoundsShowsTheResultAndCleansUp() async throws {
        try await LibrarySoundsFolder.preserved {
            let driver = await makeDriver()
            defer { driver.close() }

            await driver.selectSegment(2)
            await #expect(driver.waitUntil { driver.rowCount(inSection: 1) < 50 })
            // "Import system sounds" is the last row of the system section.
            await driver.tapRow(IndexPath(item: driver.rowCount(inSection: 1) - 1, section: 1))
            await #expect(driver.waitUntil(timeout: 30) { driver.alert != nil })
            await driver.tapAlertButton()
        }
    }

    /// On the Mac the screen explains where to drop sounds instead of offering the importers, and
    /// lists no imported sounds.
    @Test func rendersTheMacLayout() async {
        let previousCatalyst = Current.isCatalyst
        Current.isCatalyst = true
        defer { Current.isCatalyst = previousCatalyst }

        let driver = await makeDriver()
        defer { driver.close() }
        #expect(driver.sectionCount == 2)
        // The instructions and the "open folder" button, with no imported sounds above them.
        #expect(driver.rowCount(inSection: 1) == 2)
    }

    /// A sound file that cannot be played reports the error instead of playing.
    @Test func aBrokenSoundReportsTheError() async throws {
        let folder = try NotificationSoundsViewModel().librarySoundsURL()
        let broken = folder.appendingPathComponent("zzzz-b2-broken-\(UUID().uuidString).wav")
        try Data("not a sound".utf8).write(to: broken)
        defer { try? FileManager.default.removeItem(at: broken) }

        let driver = await makeDriver()
        defer { driver.close() }

        // Imported sounds are sorted by name, so the broken one comes right before the two import buttons.
        let row = driver.rowCount(inSection: 1) - 3
        try #require(row >= 0)
        await driver.tapRow(IndexPath(item: row, section: 1))

        // The playback error is shown in an error alert.
        await #expect(driver.waitUntil { driver.alert != nil })
        #expect(driver.alert?.title == L10n.errorLabel)
        await driver.tapAlertButton()
    }

    /// The help button opens the sounds documentation in the browser.
    @Test func helpOpensTheSoundsDocumentation() async throws {
        try await RecordingURLOpener.with { opener in
            let driver = await makeDriver()
            defer { driver.close() }
            try #require(!driver.barButtons.isEmpty)
            await driver.tapBarButton(0)
            #expect(opener.openedURLs.map(\.url.absoluteString) == [
                "https://companion.home-assistant.io/app/ios/notifications-sounds",
            ])
        }
    }
}
