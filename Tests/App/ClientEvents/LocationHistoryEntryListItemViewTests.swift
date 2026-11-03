import CoreLocation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// A location history row shows when and why the location was recorded, and opens the detail map;
/// its preview configuration renders as well.
///
/// `.sharedState`: following the row builds the detail screen during a SwiftUI update on the main
/// run loop, where it reads the global `Current.database`, which the test swaps.
@Suite(.sharedState)
@MainActor
struct LocationHistoryEntryListItemViewTests {
    private func formatter() -> DateFormatter {
        with(DateFormatter()) {
            $0.dateStyle = .short
            $0.timeStyle = .medium
        }
    }

    @Test func theRowOpensTheDetailMap() async throws {
        let entry = LocationHistoryEntry(
            updateType: .RegionExit,
            location: CLLocation(latitude: 52.37, longitude: 4.89),
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "{}"
        )
        try await SettingsTestDatabase.with({ db in try entry.insert(db) }) { _ in
            let driver = await SwiftUIScreenDriver.show(List {
                LocationHistoryEntryListItemView(entry: entry, dateFormatter: formatter())
                LocationHistoryEntryListItemView(
                    entry: with(entry) { $0.trigger = nil },
                    dateFormatter: formatter()
                )
            })
            defer { driver.close() }

            await #expect(driver.waitUntil { driver.rows.count == 2 })
            await #expect(driver.push(IndexPath(item: 0, section: 0)))
            #expect(driver.depth == 2)
            await driver.pop()
        }
    }

    @Test func thePreviewConfigurationRenders() async {
        let configuration = LocationHistoryEntryListItemView_Previews.configuration
        #expect(configuration.configurations.count == 1)
        let driver = await SwiftUIScreenDriver.show(LocationHistoryEntryListItemView_Previews.previews)
        driver.close()
    }
}
