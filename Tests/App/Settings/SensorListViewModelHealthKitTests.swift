@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class SensorListViewModelHealthKitTests: XCTestCase {
    private var originalHealthKit: AppEnvironment.HealthKit!
    private var previousDisabledSensors: Any?

    override func setUp() {
        super.setUp()

        originalHealthKit = Current.healthKit
        previousDisabledSensors = Current.settingsStore.prefs.object(forKey: "disabledSensors")

        Current.settingsStore.prefs.removeObject(forKey: "disabledSensors")
        Current.healthKit.isAvailable = { true }
        Current.healthKit.authorizationStatus = { .available }
    }

    override func tearDown() {
        restore(previousDisabledSensors, forKey: "disabledSensors")
        Current.healthKit = originalHealthKit
        originalHealthKit = nil
        super.tearDown()
    }

    private func restore(_ value: Any?, forKey key: String) {
        if let value {
            Current.settingsStore.prefs.set(value, forKey: key)
        } else {
            Current.settingsStore.prefs.removeObject(forKey: key)
        }
    }

    func testRequestHealthAuthorizationRefreshesHealthKitStatus() throws {
        var requested = false
        var status = HealthKitSensor.AuthorizationStatus.unavailable
        Current.healthKit.authorizationStatus = { status }
        Current.healthKit.requestReadAuthorization = {
            requested = true
            status = .available
            return .value(())
        }
        let viewModel = SensorListViewModel()

        try hang(viewModel.requestHealthAuthorization())

        XCTAssertTrue(requested)
        XCTAssertEqual(viewModel.healthKitStatus, .available)
    }

    func testUpdatePermissionsUsesHealthKitStatus() {
        Current.healthKit.authorizationStatus = { .unavailable }
        let viewModel = SensorListViewModel()

        viewModel.updatePermissions()

        XCTAssertEqual(viewModel.healthKitStatus, .unavailable)
    }

    func testUpdateAllSensorsIncludesHealthSensors() {
        Current.sensors.setEnabled(false, forUniqueID: HealthKitSensor.Metric.steps.uniqueID)
        let viewModel = SensorListViewModel()
        viewModel.sensors = [
            WebhookSensor(name: "Health Steps", uniqueID: HealthKitSensor.Metric.steps.uniqueID),
        ]

        viewModel.updateAllSensors(isEnabled: true)

        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: HealthKitSensor.Metric.steps.uniqueID))
    }
}
