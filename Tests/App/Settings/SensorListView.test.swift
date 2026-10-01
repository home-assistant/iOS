@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Sensors are chosen per server, so the root screen shows either one server's sensors or the list
/// of servers to pick one — which is the difference these cover.
///
/// Serialized because `withServers` swaps globals on `Current`.
@Suite(.serialized)
struct SensorListViewTests {
    @MainActor
    @Test func sensorListWithOneServerShowsItsSensors() throws {
        try withServers(count: 1) { _ in
            assertLightDarkSnapshots(of: NavigationView { SensorListView() }, drawHierarchyInKeyWindow: true)
        }
    }

    @MainActor
    @Test func sensorListWithSeveralServersListsThem() throws {
        try withServers(count: 3) { _ in
            assertLightDarkSnapshots(of: NavigationView { SensorListView() }, drawHierarchyInKeyWindow: true)
        }
    }

    @MainActor
    @Test func serverScopedSensorListIsTitledAfterItsServer() throws {
        try withServers(count: 2) { servers in
            let server = try #require(servers.all.first)
            assertLightDarkSnapshots(
                of: NavigationView { SensorListView(server: server) },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    @MainActor
    @Test func serverScopedSensorListShowsItsSensors() throws {
        try withServers(count: 2) { servers in
            let server = try #require(servers.all.first)
            let viewModel = SensorListViewModel(server: server)
            viewModel.sensors = [
                WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue, state: "Walking"),
                WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue, state: "12 GB"),
            ]
            assertLightDarkSnapshots(
                of: NavigationView { SensorListView(server: server, viewModel: viewModel) },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    @MainActor
    @Test func sensorListSaysWhenASearchMatchesNothing() throws {
        try withServers(count: 2) { servers in
            let server = try #require(servers.all.first)
            let viewModel = SensorListViewModel(server: server)
            viewModel.sensors = [WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)]
            viewModel.searchTerm = "nothing matches this"
            assertLightDarkSnapshots(
                of: NavigationView { SensorListView(server: server, viewModel: viewModel) },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    /// The screen reads the servers and the selection straight out of `Current`, so both are put
    /// back afterwards rather than left for whatever test runs next.
    @MainActor
    private func withServers(count: Int, _ body: (FakeServerManager) throws -> Void) throws {
        let previousServers = Current.servers
        let previousSensors = Current.sensors
        // Shared app group defaults, so whatever ran before could have moved this and changed the
        // row the snapshot renders.
        let previousInterval = Current.settingsStore.periodicUpdateInterval
        defer {
            Current.servers = previousServers
            Current.sensors = previousSensors
            Current.settingsStore.periodicUpdateInterval = previousInterval
            SensorEnablementStore.resetForTesting()
        }
        Current.settingsStore.periodicUpdateInterval = 300

        // Named apart rather than left as identical fakes: `Server` sorts on name once sort orders
        // tie, so same-named servers would come out in whatever order the snapshot happened to get.
        let servers = FakeServerManager()
        for index in 0 ..< count {
            let server = Server.fake(update: { $0.remoteName = "Server \(index + 1)" })
            servers.add(identifier: server.identifier, serverInfo: server.info)
        }
        Current.servers = servers
        SensorEnablementStore.resetForTesting()
        Current.sensors = SensorContainer()
        // Without this the store assumes an upgrade and hands every server the legacy-era selection,
        // which would put the same large count against all of them.
        Current.sensors.resetSensorsForFirstRun()
        // Different counts per server, which is what the list of servers is there to show.
        if let first = servers.all.first {
            Current.sensors.setEnabled(
                true,
                forUniqueIDs: [WebhookSensorId.activity.rawValue, WebhookSensorId.storage.rawValue],
                on: first
            )
        }
        try body(servers)
    }
}
