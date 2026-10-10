import CoreLocation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

struct LocationHistoryEntryDebugReportTests {
    private let home = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    /// Runs `body` with a throwaway database holding the given zones.
    private func withZones(_ zones: [AppZone], _ body: () throws -> Void) throws {
        let database = try DatabaseQueue()
        try AppZoneTable().createIfNeeded(database: database)
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }
        zones.forEach { $0.save() }
        try body()
    }

    private func entry(
        trigger: LocationUpdateTrigger = .Manual,
        accuracy: CLLocationAccuracy = 10,
        authorization: CLAccuracyAuthorization = .fullAccuracy
    ) -> LocationHistoryEntry {
        LocationHistoryEntry(
            updateType: trigger,
            location: CLLocation(
                coordinate: home,
                altitude: 0,
                horizontalAccuracy: accuracy,
                verticalAccuracy: 0,
                timestamp: Date()
            ),
            zone: nil,
            accuracyAuthorization: authorization,
            payload: "{\"gps\": [37.7749, -122.4194]}"
        )
    }

    @Test func reportDescribesThePayloadAndTheLocation() throws {
        try withZones([]) {
            let report = entry().debugReport()
            #expect(report.hasPrefix("# Debug Information"))
            #expect(report.contains("{\"gps\": [37.7749, -122.4194]}"))
            #expect(report.contains("- Trigger: Manual"))
            #expect(report.contains("- Center: (37.774900, -122.419400)"))
            #expect(report.contains("- Accuracy: 10.00m\n"))
            #expect(report.contains("- Accuracy Authorization: full"))
            #expect(report.hasSuffix("## Regions\n"))
        }
    }

    @Test func reportNamesTheSourceOfKnownAccuracies() throws {
        try withZones([]) {
            #expect(entry(accuracy: 65).debugReport().contains("- Accuracy: 65.00m (from Wi-Fi)"))
            #expect(entry(accuracy: 1414).debugReport().contains("- Accuracy: 1414.00m (from cell tower)"))
            #expect(entry(authorization: .reducedAccuracy).debugReport().contains("- Accuracy Authorization: reduced"))
        }
    }

    @Test func reportListsEveryMonitoredRegionNearestFirst() throws {
        let server = FakeServerManager(initial: 1).all[0].identifier.rawValue
        let zones = [
            AppZone(
                entityId: "zone.far",
                serverIdentifier: server,
                latitude: 40.7128,
                longitude: -74.0060,
                radius: 100
            ),
            AppZone(
                entityId: "zone.home",
                serverIdentifier: server,
                latitude: home.latitude,
                longitude: home.longitude,
                radius: 100
            ),
        ]
        try withZones(zones) {
            let report = entry().debugReport()
            let homeRange = try #require(report.range(of: "### \(zones[1].identifier)"))
            let farRange = try #require(report.range(of: "### \(zones[0].identifier)"))
            #expect(homeRange.lowerBound < farRange.lowerBound)
            #expect(report.contains("- Radius: 100.00m"))
            #expect(report.contains("- Relative State: inside"))
            #expect(report.contains("- Relative State: outside"))
        }
    }
}
