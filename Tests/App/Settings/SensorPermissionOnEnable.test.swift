@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

/// Sensors are opt-in, so switching one on is the only moment the app learns someone wants it, and
/// the permission it needs has to be asked for right then.
class SensorPermissionOnEnableTests: XCTestCase {
    private var originalSensors: SensorContainer!
    private var originalServers: ServerManager!
    private var server: Server!
    private var originalRequest: (([String]) -> Void)!
    private var requestedUniqueIDs: [[String]] = []

    override func setUp() {
        super.setUp()

        originalSensors = Current.sensors
        originalServers = Current.servers
        originalRequest = Current.requestSensorPermissions
        requestedUniqueIDs = []

        let servers = FakeServerManager()
        server = servers.addFake()
        Current.servers = servers
        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()
        // Without this the store assumes an upgrade and switches the legacy-era sensors on, so a
        // test about switching one on would start with it already enabled.
        Current.sensors.resetSensorsForFirstRun()
        Current.requestSensorPermissions = { [weak self] uniqueIDs in
            self?.requestedUniqueIDs.append(uniqueIDs)
        }
    }

    override func tearDown() {
        SensorEnablementStore.resetForTesting()
        Current.requestSensorPermissions = originalRequest
        Current.sensors = originalSensors
        Current.servers = originalServers
        server = nil
        originalSensors = nil
        originalServers = nil
        originalRequest = nil
        super.tearDown()
    }

    // MARK: - What each sensor needs

    func testSensorsThatNeedAPermissionAreMappedToIt() {
        XCTAssertEqual(SensorPermission.required(forSensorUniqueID: WebhookSensorId.activity.rawValue), .motion)
        XCTAssertEqual(SensorPermission.required(forSensorUniqueID: WebhookSensorId.pressure.rawValue), .motion)
        XCTAssertEqual(SensorPermission.required(forSensorUniqueID: WebhookSensorId.focus.rawValue), .focus)
        XCTAssertEqual(SensorPermission.required(forSensorUniqueID: WebhookSensorId.focusName.rawValue), .focus)
        XCTAssertEqual(
            SensorPermission.required(forSensorUniqueID: WebhookSensorId.connectivitySSID.rawValue),
            .location
        )
        XCTAssertEqual(
            SensorPermission.required(forSensorUniqueID: WebhookSensorId.cameraMotion.rawValue),
            .camera
        )

        for uniqueID in PedometerSensor.allSensorIDs {
            XCTAssertEqual(SensorPermission.required(forSensorUniqueID: uniqueID), .motion, uniqueID)
        }
    }

    func testSensorsThatNeedNoPermissionAreMappedToNothing() {
        XCTAssertNil(SensorPermission.required(forSensorUniqueID: WebhookSensorId.storage.rawValue))
        XCTAssertNil(SensorPermission.required(forSensorUniqueID: WebhookSensorId.appVersion.rawValue))
        // Apple Health asks per data type, from its own screen.
        XCTAssertNil(SensorPermission.required(forSensorUniqueID: HealthKitMetric.restingHeartRate.uniqueID))
    }

    // MARK: - Switching sensors on

    func testEnablingASensorFromTheListAsksForItsPermission() {
        let viewModel = SensorListViewModelWithoutRefresh()
        let sensor = WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)

        viewModel.setEnabled(true, for: sensor)

        XCTAssertEqual(requestedUniqueIDs, [[WebhookSensorId.activity.rawValue]])
        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: server))
    }

    func testSwitchingASensorOffAsksForNothing() {
        let viewModel = SensorListViewModelWithoutRefresh()
        let sensor = WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)
        viewModel.setEnabled(true, for: sensor)
        requestedUniqueIDs = []

        viewModel.setEnabled(false, for: sensor)

        XCTAssertTrue(requestedUniqueIDs.isEmpty)
    }

    func testEnablingEverythingAsksOnceForTheWholeSelection() {
        let viewModel = SensorListViewModelWithoutRefresh()
        viewModel.sensors = [
            WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue),
            WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue),
        ]

        viewModel.updateAllSensors(isEnabled: true)

        XCTAssertEqual(requestedUniqueIDs.count, 1)
        XCTAssertEqual(
            requestedUniqueIDs.first.map(Set.init),
            Set([WebhookSensorId.activity.rawValue, WebhookSensorId.storage.rawValue])
        )
    }

    func testEnablingASensorFromItsDetailScreenAsksForItsPermission() {
        let sensor = WebhookSensor(name: "Focus", uniqueID: WebhookSensorId.focus.rawValue)
        let viewModel = SensorDetailViewModel(sensor: sensor, server: server)

        viewModel.setEnabled(true)

        XCTAssertEqual(requestedUniqueIDs, [[WebhookSensorId.focus.rawValue]])
    }

    /// The detail screen follows the sensor as later updates arrive, and each of them re-reads the
    /// enablement for the server it is configuring rather than for whichever came first.
    func testDetailScreenFollowsTheSensorForItsOwnServer() {
        let sensor = WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue)
        let viewModel = SensorDetailViewModel(sensor: sensor, server: server)
        XCTAssertFalse(viewModel.isEnabled)

        Current.sensors.setEnabled(true, forUniqueID: WebhookSensorId.storage.rawValue, on: server)
        let updated = WebhookSensor(
            name: "Storage",
            uniqueID: WebhookSensorId.storage.rawValue,
            state: "12 GB"
        )
        viewModel.sensorContainer(Current.sensors, didUpdate: .init(sensors: .value([updated])))

        let populated = expectation(description: "the update reaches the screen")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { populated.fulfill() }
        wait(for: [populated], timeout: 2)

        XCTAssertTrue(viewModel.isEnabled)
        XCTAssertEqual(viewModel.stateDescription, updated.StateDescription)
    }

    private final class SensorListViewModelWithoutRefresh: SensorListViewModel {
        override func refresh() {}
    }
}
