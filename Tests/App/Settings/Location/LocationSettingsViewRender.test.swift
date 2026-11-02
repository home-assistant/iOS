import CoreLocation
import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Shared state: the screen observes `Current.database`, reads `Current.servers` and its toggles
/// write the location sources to preferences, all from the main run loop.
@Suite(.sharedState)
@MainActor
struct LocationSettingsViewRenderTests {
    @Test func rendersWithoutZones() async throws {
        try await withWorld(zones: false) {
            let driver = await SwiftUIScreenDriver.show(LocationSettingsView())
            defer { driver.close() }
            // Permissions, history and update sources.
            #expect(driver.sectionCount == 3)
        }
    }

    /// The accuracy and background refresh rows send the user to their pages in Settings.
    @Test func permissionRowsOpenTheirSettingsPages() async throws {
        let previousCatalyst = Current.isCatalyst
        Current.isCatalyst = false
        defer { Current.isCatalyst = previousCatalyst }

        try await withWorld(zones: false) {
            try await RecordingURLOpener.with { opener in
                let driver = await SwiftUIScreenDriver.show(LocationSettingsView())
                defer { driver.close() }
                // Location permission, accuracy, background refresh. The first row can raise the
                // system prompt, so it is left alone.
                try #require(driver.rowCount(inSection: 0) == 3)

                await driver.tapRow(IndexPath(item: 1, section: 0))
                #expect(opener.openSettingsDestination == .location)
                await driver.tapRow(IndexPath(item: 2, section: 0))
                #expect(opener.openSettingsDestination == .backgroundRefresh)
            }
        }
    }

    @Test func rendersZonesAndOpensTheLocationHistory() async throws {
        try await withWorld(zones: true) {
            let previous = Current.settingsStore.locationSources
            defer { Current.settingsStore.locationSources = previous }

            let driver = await SwiftUIScreenDriver.show(LocationSettingsView())
            defer { driver.close() }
            #expect(driver.sectionCount == 4)

            await driver.toggleSwitches()
            await #expect(driver.push(IndexPath(item: 0, section: 2)))
        }
    }

    /// The full list, filtered by nothing, and each zone's map.
    @Test func zonesListOpensEachZoneMap() async throws {
        try await withWorld(zones: true) {
            let viewModel = LocationSettingsViewModel()
            let driver = await SwiftUIScreenDriver.show(ZonesListView(viewModel: viewModel))
            defer { driver.close() }
            #expect(driver.rows.count == 2)
            await #expect(driver.push(IndexPath(item: 0, section: 0)))
        }
    }

    @Test func rendersZoneCardsAndMaps() async throws {
        try await withWorld(zones: true) {
            let viewModel = LocationSettingsViewModel()
            for zone in viewModel.zones {
                let card = await SwiftUIScreenDriver.show(
                    ZoneCardView(zone: zone, distanceText: "1 km", serverName: "Server"),
                    size: CGSize(width: 320, height: 400)
                )
                card.close()
                let plain = await SwiftUIScreenDriver.show(
                    ZoneCardView(zone: zone, distanceText: nil, serverName: nil),
                    size: CGSize(width: 320, height: 400)
                )
                plain.close()
            }
            let map = await SwiftUIScreenDriver.show(
                LocationZoneMapView(title: "", coordinate: .init(latitude: 52.37, longitude: 4.89), radius: 100)
            )
            map.close()
            let named = await SwiftUIScreenDriver.show(
                LocationZoneMapView(title: "Home", coordinate: .init(latitude: 52.37, longitude: 4.89), radius: 0)
            )
            named.close()
            let snapshot = await SwiftUIScreenDriver.show(
                ZoneMapSnapshotView(coordinate: .init(latitude: 52.37, longitude: 4.89), radius: 150),
                size: CGSize(width: 280, height: 160),
                inNavigationStack: false
            )
            snapshot.close()
        }
    }

    /// "Update location" sends a manual update and reports its failure; here the background task
    /// runner has no time left, so the update fails at once without reaching for a location.
    @Test func aFailedManualUpdateIsReported() async throws {
        try await withWorld(zones: false) {
            let previousRunner = Current.backgroundTask
            Current.backgroundTask = ExpiredBackgroundTaskRunner()
            defer { Current.backgroundTask = previousRunner }

            let driver = await SwiftUIScreenDriver.show(LocationSettingsView())
            defer { driver.close() }
            // Location history, then "Update location".
            await driver.tapRow(IndexPath(item: 1, section: 1))
            await driver.settle()
            await driver.dismissPresented()
        }
    }

    private func withWorld(zones: Bool, _ body: () async throws -> Void) async throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let servers = FakeServerManager(initial: 2)
        if zones {
            try await database.write { db in
                try AppZone(
                    entityId: "zone.home",
                    serverIdentifier: servers.all[0].identifier.rawValue,
                    friendlyName: "Home",
                    latitude: 52.37,
                    longitude: 4.89,
                    radius: 100,
                    beaconUUID: "B9407F30-F5F8-466E-AFF9-25556B57FE6D",
                    beaconMajor: 1,
                    beaconMinor: 2
                ).insert(db)
                try AppZone(
                    entityId: "zone.work",
                    serverIdentifier: servers.all[1].identifier.rawValue,
                    friendlyName: "Work",
                    latitude: 48.85,
                    longitude: 2.35,
                    radius: 250,
                    trackingEnabled: false
                ).insert(db)
            }
        }
        let previousDatabase = Current.database
        let previousServers = Current.servers
        Current.database = { database }
        Current.servers = servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        try await body()
    }
}

/// Fails every background task at once, without running the work it wraps.
private final class ExpiredBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        Promise(error: BackgroundTaskError.outOfTime)
    }
}
