@testable import HomeAssistant
@testable import Shared
import Testing

/// The hinge sensors can only be switched on on a device that folds. Anywhere else they move to a
/// section of their own at the bottom of the list, which these cover.
///
/// Serialized because each test swaps `Current.hinge`, `Current.servers` and `Current.sensors`.
@Suite(.serialized)
@MainActor
struct SensorListViewModelDeviceAvailabilityTests {
    @Test func withoutAHingeTheHingeSensorsAreUnavailable() async throws {
        try await withServer(hasHinge: false) { server in
            let viewModel = SensorListViewModelWithoutRefresh(server: server)
            viewModel.sensors = [Self.activity] + HingeSensor.unreadSensors()

            #expect(!viewModel.deviceHasHinge)
            #expect(viewModel.filteredSensors.map(\.UniqueID) == [WebhookSensorId.activity.rawValue])
            #expect(viewModel.filteredUnavailableSensors.map(\.UniqueID) == Self.hingeSensorIDs)
        }
    }

    /// The providers stop listing the hinge sensors once a device says it has no hinge, so the
    /// section is complete whether or not any of them made it into the list first.
    @Test func everyHingeSensorIsListedAsUnavailableEvenWhenNoneWereReported() async throws {
        try await withServer(hasHinge: false) { server in
            let viewModel = SensorListViewModelWithoutRefresh(server: server)
            viewModel.sensors = [Self.activity]

            #expect(viewModel.unavailableSensors.map(\.UniqueID) == Self.hingeSensorIDs)
            #expect(viewModel.unavailableSensors.map(\.Name) == ["Hinge Angle", "Hinge Status", "Pose"])
        }
    }

    @Test func withAHingeTheHingeSensorsAreAvailable() async throws {
        try await withServer(hasHinge: true) { server in
            let viewModel = SensorListViewModelWithoutRefresh(server: server)
            viewModel.sensors = [Self.activity] + HingeSensor.unreadSensors() + [DevicePoseSensor.unreadSensor()]

            #expect(viewModel.deviceHasHinge)
            #expect(viewModel.filteredSensors.count == 4)
            #expect(viewModel.unavailableSensors.isEmpty)
        }
    }

    /// The hinge is reported a moment after launch, so a screen opened before then has to move the
    /// sensors back up once it is.
    @Test func aHingeReportedAfterTheScreenOpenedMakesTheSensorsAvailable() async throws {
        try await withServer(hasHinge: false) { server in
            let viewModel = SensorListViewModelWithoutRefresh(server: server)
            viewModel.sensors = [Self.activity] + HingeSensor.unreadSensors()
            #expect(!viewModel.unavailableSensors.isEmpty)

            Current.hinge.setState(HingeState(angleDegrees: 90, status: .partiallyOpen))
            await settle { viewModel.deviceHasHinge }

            #expect(viewModel.unavailableSensors.isEmpty)
            #expect(viewModel.filteredSensors.count == 3)
        }
    }

    /// The section stays out until the list has loaded, rather than sitting alone under an empty
    /// list of sensors.
    @Test func nothingIsUnavailableBeforeTheListLoads() async throws {
        try await withServer(hasHinge: false) { server in
            #expect(SensorListViewModelWithoutRefresh(server: server).unavailableSensors.isEmpty)
        }
    }

    /// Nothing on the screen could switch an unavailable sensor back off, so enabling everything
    /// leaves them alone, and they do not hold the switch off either.
    @Test func enableAllCoversOnlyTheAvailableSensors() async throws {
        try await withServer(hasHinge: false) { server in
            let viewModel = SensorListViewModelWithoutRefresh(server: server)
            viewModel.sensors = [Self.activity] + HingeSensor.unreadSensors()

            viewModel.updateAllSensors(isEnabled: true)

            #expect(viewModel.allSensorsEnabled)
            #expect(Current.sensors.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: server))
            for id in Self.hingeSensorIDs {
                #expect(!Current.sensors.isEnabled(uniqueID: id, for: server))
            }
        }
    }

    @Test func searchingLooksThroughTheUnavailableSensorsToo() async throws {
        try await withServer(hasHinge: false) { server in
            let viewModel = SensorListViewModelWithoutRefresh(server: server)
            viewModel.sensors = [Self.activity]

            viewModel.searchTerm = "hinge"

            #expect(viewModel.filteredSensors.isEmpty)
            #expect(viewModel.filteredUnavailableSensors.map(\.UniqueID) == [
                WebhookSensorId.hingeAngle.rawValue,
                WebhookSensorId.hingeStatus.rawValue,
            ])
        }
    }

    // MARK: - Helpers

    private static let activity = WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)

    private static let hingeSensorIDs = [
        WebhookSensorId.hingeAngle.rawValue,
        WebhookSensorId.hingeStatus.rawValue,
        WebhookSensorId.devicePose.rawValue,
    ]

    /// `refresh()` asks the real `HomeAssistantAPI` for an update, which a unit test has no server
    /// to answer with.
    private final class SensorListViewModelWithoutRefresh: SensorListViewModel {
        override func refresh() {}
    }

    /// The model hands the hinge to the main queue, so a test reading it straight afterwards would
    /// see the value from before.
    private func settle(until condition: () -> Bool) async {
        for _ in 0 ..< 200 where !condition() {
            try? await Task.sleep(nanoseconds: 5 * NSEC_PER_MSEC)
        }
    }

    private func withServer(hasHinge: Bool, _ body: (Server) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousSensors = Current.sensors
        let previousHinge = Current.hinge
        defer {
            Current.servers = previousServers
            Current.sensors = previousSensors
            Current.hinge = previousHinge
            SensorEnablementStore.resetForTesting()
        }

        let servers = FakeServerManager(initial: 1)
        Current.servers = servers
        SensorEnablementStore.resetForTesting()
        Current.sensors = SensorContainer()
        // Without this the store assumes an upgrade and hands the server the legacy-era selection,
        // which is not the opt-in state these are about.
        Current.sensors.resetSensorsForFirstRun()
        // Supported regardless of the simulator's OS, so the hinge decides rather than the system.
        Current.hinge = HingeObserver(isSupported: true)
        if hasHinge {
            Current.hinge.setState(HingeState(angleDegrees: 90, status: .partiallyOpen))
        }
        try await body(#require(servers.all.first))
    }
}
