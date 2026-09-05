@testable import HomeAssistant
@testable import Shared
import XCTest

/// Sensors are opt-in, so switching one on is the only moment the app learns someone wants it, and
/// the permission it needs has to be asked for right then.
class SensorPermissionOnEnableTests: XCTestCase {
    private var originalSensors: SensorContainer!
    private var originalRequest: (([String]) -> Void)!
    private var requestedUniqueIDs: [[String]] = []

    override func setUp() {
        super.setUp()

        originalSensors = Current.sensors
        originalRequest = Current.requestSensorPermissions
        requestedUniqueIDs = []

        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()
        Current.requestSensorPermissions = { [weak self] uniqueIDs in
            self?.requestedUniqueIDs.append(uniqueIDs)
        }
    }

    override func tearDown() {
        SensorEnablementStore.resetForTesting()
        Current.requestSensorPermissions = originalRequest
        Current.sensors = originalSensors
        originalSensors = nil
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
        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: WebhookSensorId.activity.rawValue))
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
        let viewModel = SensorDetailViewModel(sensor: sensor)

        viewModel.setEnabled(true)

        XCTAssertEqual(requestedUniqueIDs, [[WebhookSensorId.focus.rawValue]])
    }

    private final class SensorListViewModelWithoutRefresh: SensorListViewModel {
        override func refresh() {}
    }
}
