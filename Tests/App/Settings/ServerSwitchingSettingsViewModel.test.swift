import CoreLocation
import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

final class ServerSwitchingSettingsViewModelTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousServers: ServerManager!
    private var previousNetworkState: (() async -> NetworkState)!
    private var servers: FakeServerManager!
    private var server1: Server!
    private var server2: Server!

    // Two far-apart home zones, roughly San Francisco and New York.
    private let home1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    private let home2 = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        try AppZoneTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }

        servers = FakeServerManager(initial: 2)
        server1 = servers.all[0]
        server2 = servers.all[1]
        previousServers = Current.servers
        Current.servers = servers

        // No Wi-Fi unless a test says otherwise, so the runner's own network cannot match a server.
        previousNetworkState = Current.connectivity.currentNetworkState
        Current.connectivity.currentNetworkState = { NetworkState() }
    }

    override func tearDown() {
        Current.database = previousDatabase
        Current.servers = previousServers
        Current.connectivity.currentNetworkState = previousNetworkState
        super.tearDown()
    }

    @MainActor
    func testDescribesTheServerMatchedByItsHomeNetwork() async throws {
        server1.update { $0.connection.internalSSIDs = ["home1-wifi"] }
        server2.update { $0.connection.internalSSIDs = ["home2-wifi"] }
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "home2-wifi") }

        let viewModel = ServerSwitchingSettingsViewModel()
        viewModel.onAppear()

        try await wait(for: viewModel) { $0.closestServerSource != nil }
        // Matched by the network, so the row names the server without a distance.
        XCTAssertEqual(viewModel.closestServerSource, .homeNetwork)
        XCTAssertEqual(viewModel.closestServerDescription, server2.info.name)
    }

    @MainActor
    func testDescribesTheNearestHomeZoneWithItsDistance() async throws {
        addZone(server: server1, center: home1)
        addZone(server: server2, center: home2)

        let viewModel = ServerSwitchingSettingsViewModel()
        // The screen's one-shot fix arrives through the location manager delegate.
        let nearHome2 = CLLocation(latitude: home2.latitude + 0.01, longitude: home2.longitude)
        viewModel.locationManager(CLLocationManager(), didUpdateLocations: [nearHome2])

        try await wait(for: viewModel) { $0.closestServerSource != nil }
        guard case let .location(distance) = viewModel.closestServerSource else {
            return XCTFail("Expected the location source, got \(String(describing: viewModel.closestServerSource))")
        }
        XCTAssertEqual(distance, nearHome2.distance(from: location(at: home2)), accuracy: 1)
        // The distance is formatted for the current locale, so only its separator is asserted.
        let description = try XCTUnwrap(viewModel.closestServerDescription)
        XCTAssertTrue(description.hasPrefix("\(server2.info.name) · "), "Unexpected description: \(description)")
    }

    @MainActor
    func testClearsTheRowWhenNoSignalResolvesAServer() async throws {
        // Seeded as if a previous fix had resolved a server, so the clearing is observable.
        let viewModel = ServerSwitchingSettingsViewModel(
            closestServerDescription: "Stale Server",
            closestServerSource: .homeNetwork
        )

        // No home zones are tracked and no known network is joined, so neither signal resolves one.
        viewModel.locationManager(CLLocationManager(), didUpdateLocations: [location(at: home1)])

        try await wait(for: viewModel) { $0.closestServerDescription == nil }
        XCTAssertNil(viewModel.closestServerDescription)
        XCTAssertNil(viewModel.closestServerSource)
    }

    private func addZone(entityId: String = "zone.home", server: Server, center: CLLocationCoordinate2D) {
        AppZone(
            entityId: entityId,
            serverIdentifier: server.identifier.rawValue,
            latitude: center.latitude,
            longitude: center.longitude,
            radius: 100,
            trackingEnabled: true
        ).save()
    }

    private func location(at coordinate: CLLocationCoordinate2D) -> CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// The view model resolves on a `Task`, both from `onAppear` and from the delegate, so its
    /// published values land a turn or more after the call that asks for them.
    @MainActor
    private func wait(
        for viewModel: ServerSwitchingSettingsViewModel,
        until isSettled: (ServerSwitchingSettingsViewModel) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0 ..< 200 {
            if isSettled(viewModel) { return }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        XCTFail("Timed out waiting for the view model to settle", file: file, line: line)
    }
}
