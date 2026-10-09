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

    /// A device that does not fold can never report the hinge sensors, so they sit in a section of
    /// their own at the bottom, with no switch to turn them on.
    @MainActor
    @Test func hingeSensorsAreUnavailableOnADeviceWithoutAHinge() throws {
        try withServers(count: 2) { servers in
            let server = try #require(servers.all.first)
            let viewModel = SensorListViewModel(server: server)
            viewModel.sensors = [
                WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue, state: "Walking"),
            ]
            assertLightDarkSnapshots(
                of: NavigationView { SensorListView(server: server, viewModel: viewModel) },
                drawHierarchyInKeyWindow: true,
                // Tall enough for the whole list: the section this covers sits at the very bottom,
                // below the fold of a phone-sized frame.
                layout: .fixed(width: 390, height: 2200)
            )
        }
    }

    /// On a device that folds they are sensors like any other, each with its own switch.
    @MainActor
    @Test func hingeSensorsCanBeSwitchedOnOnADeviceWithAHinge() throws {
        try withServers(count: 2) { servers in
            let server = try #require(servers.all.first)
            let state = HingeState(angleDegrees: 118.5, status: .partiallyOpen)
            Current.hinge.setState(state)
            Current.sensors.setEnabled(true, forUniqueID: WebhookSensorId.hingeAngle.rawValue, on: server)
            let viewModel = SensorListViewModel(server: server)
            viewModel.sensors = [
                HingeSensor.angleSensor(for: state),
                HingeSensor.statusSensor(for: state),
                DevicePoseSensor.sensor(for: .laptop),
            ]
            assertLightDarkSnapshots(
                of: NavigationView { SensorListView(server: server, viewModel: viewModel) },
                drawHierarchyInKeyWindow: true,
                // Tall enough for all three, which run past the fold of a phone-sized frame.
                layout: .fixed(width: 390, height: 2200)
            )
        }
    }

    /// The screen reads the servers, the selection and the hinge straight out of `Current`, so all
    /// three are put back afterwards rather than left for whatever test runs next.
    @MainActor
    private func withServers(count: Int, _ body: (FakeServerManager) throws -> Void) throws {
        let previousServers = Current.servers
        let previousSensors = Current.sensors
        let previousHinge = Current.hinge
        // Shared app group defaults, so whatever ran before could have moved this and changed the
        // row the snapshot renders.
        let previousInterval = Current.settingsStore.periodicUpdateInterval
        defer {
            Current.servers = previousServers
            Current.sensors = previousSensors
            Current.hinge = previousHinge
            Current.settingsStore.periodicUpdateInterval = previousInterval
            SensorEnablementStore.resetForTesting()
        }
        Current.settingsStore.periodicUpdateInterval = 300
        // Supported whatever the simulator's OS, and without a hinge until a test reports one, so
        // which section the hinge sensors land in is the test's choice rather than the machine's.
        Current.hinge = HingeObserver(isSupported: true)

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
