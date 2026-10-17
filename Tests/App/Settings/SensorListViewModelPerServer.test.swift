import Combine
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

/// The sensor list is scoped to one server, or to none on the root screen of an install with
/// several. These cover what that scoping changes.
@Suite(.serialized)
@MainActor
struct SensorListViewModelPerServerTests {
    @Test func aScopedModelReportsOnlyItsOwnServersSelection() async throws {
        try await withServers { servers in
            let first = try #require(servers.all.first)
            let second = try #require(servers.all.last)
            Current.sensors.setEnabled(true, forUniqueID: WebhookSensorId.activity.rawValue, on: first)

            let viewModel = SensorListViewModel(server: first)
            let sensor = WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)

            #expect(viewModel.isEnabled(sensor))
            #expect(!SensorListViewModel(server: second).isEnabled(sensor))
        }
    }

    /// A sensor with no unique ID cannot be matched against a selection, so it reads as off rather
    /// than taking the state of whatever happens to be first.
    @Test func aSensorWithoutAUniqueIDIsNeverEnabled() async throws {
        try await withServers { servers in
            let server = try #require(servers.all.first)
            let viewModel = SensorListViewModel(server: server)

            #expect(!viewModel.isEnabled(WebhookSensor()))
        }
    }

    @Test func enableAllReflectsWhetherEverySensorShownIsOn() async throws {
        try await withServers { servers in
            let server = try #require(servers.all.first)
            let viewModel = SensorListViewModel(server: server)
            let activity = WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)
            let storage = WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue)
            viewModel.sensors = [activity, storage]

            // An empty list is not "all of them are on", or the switch would read on with nothing
            // behind it.
            #expect(!SensorListViewModel(server: server).allSensorsEnabled)

            viewModel.updateAllSensors(isEnabled: true)
            #expect(viewModel.allSensorsEnabled)

            viewModel.updateAllSensors(isEnabled: false)
            #expect(!viewModel.allSensorsEnabled)
        }
    }

    @Test func serversAreOfferedOnlyWhenThereIsMoreThanOne() async throws {
        try await withServers { servers in
            #expect(SensorListViewModel(server: nil).selectableServers.count == 2)

            try servers.remove(identifier: #require(servers.all.last).identifier)

            // With one server its sensors are shown on the root screen itself, so there is nothing
            // to pick between.
            #expect(SensorListViewModel(server: nil).selectableServers.isEmpty)
        }
    }

    /// An already-open screen has to follow servers coming and going, or it keeps offering one that
    /// has been removed.
    @Test func theServerListFollowsServersBeingAddedAndRemoved() async throws {
        try await withServers { servers in
            let viewModel = SensorListViewModelWithoutRefresh(server: nil)
            #expect(viewModel.selectableServers.count == 2)

            // The fake registry stores the change without announcing it, which the real one does.
            let added = servers.addFake()
            servers.notify()
            await settle { viewModel.servers.count == 3 }
            #expect(viewModel.selectableServers.count == 3)

            servers.remove(identifier: added.identifier)
            servers.notify()
            await settle { viewModel.servers.count == 2 }
            #expect(viewModel.selectableServers.count == 2)
        }
    }

    /// The root screen lists servers rather than sensors, so that is what its search looks through.
    @Test func searchingTheRootScreenFiltersTheServers() async throws {
        try await withServers { servers in
            let viewModel = SensorListViewModelWithoutRefresh(server: nil)
            let wanted = try #require(servers.all.first)
            wanted.info.remoteName = "Holiday house"

            viewModel.searchTerm = "holiday"

            #expect(viewModel.filteredServers.map(\.identifier) == [wanted.identifier])
        }
    }

    /// The root screen lists the servers rather than anything a selection changes, so a change on
    /// one of them leaves it alone instead of asking every server for a fresh reading.
    @Test func theRootModelIgnoresASelectionChange() async throws {
        try await withServers { _ in
            let viewModel = SensorListViewModelWithoutRefresh(server: nil)
            var republished = 0
            let token = viewModel.objectWillChange.sink { _ in republished += 1 }

            viewModel.sensorContainer(
                Current.sensors,
                didSignalForUpdateBecause: .settingsChange(changedUniqueIDs: ["activity"], serverIDs: []),
                lastUpdate: nil
            )
            await settle { republished > 0 }

            #expect(republished == 0)
            #expect(viewModel.refreshCount == 0)
            token.cancel()
        }
    }

    @Test func anUpdateFillsInTheSensorsAndWhenTheyWereRead() async throws {
        try await withServers { servers in
            let server = try #require(servers.all.first)
            Current.sensors.setEnabled(true, forUniqueID: WebhookSensorId.activity.rawValue, on: server)
            let viewModel = SensorListViewModelWithoutRefresh(server: server)

            let sensors = [
                WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue),
                WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue),
            ]
            viewModel.sensorContainer(Current.sensors, didUpdate: .init(sensors: .value(sensors)))
            await settle { viewModel.lastUpdateDate != nil }

            // Alphabetical, whichever order they arrived in.
            #expect(viewModel.sensors.compactMap(\.Name) == ["Activity", "Storage"])
            #expect(viewModel.enabledUniqueIDs == [WebhookSensorId.activity.rawValue])
            #expect(viewModel.lastUpdateDate != nil)
        }
    }

    // MARK: - Helpers

    /// `refresh()` asks the real `HomeAssistantAPI` for an update, which a unit test has no server
    /// to answer with.
    private final class SensorListViewModelWithoutRefresh: SensorListViewModel {
        private(set) var refreshCount = 0

        override func refresh() {
            refreshCount += 1
        }
    }

    /// The model hands its published changes to the main queue, so a test reading them straight
    /// afterwards would see the values from before.
    private func settle(until condition: () -> Bool) async {
        for _ in 0 ..< 200 where !condition() {
            try? await Task.sleep(nanoseconds: 5 * NSEC_PER_MSEC)
        }
    }

    private func withServers(_ body: (FakeServerManager) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousSensors = Current.sensors
        defer {
            Current.servers = previousServers
            Current.sensors = previousSensors
            SensorEnablementStore.resetForTesting()
        }

        let servers = FakeServerManager(initial: 2)
        Current.servers = servers
        SensorEnablementStore.resetForTesting()
        Current.sensors = SensorContainer()
        // Without this the store assumes an upgrade and hands both servers the legacy-era
        // selection, which is not the opt-in state these are about.
        Current.sensors.resetSensorsForFirstRun()
        try await body(servers)
    }
}
