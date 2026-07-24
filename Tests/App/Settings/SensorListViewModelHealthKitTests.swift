@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class SensorListViewModelHealthKitTests: XCTestCase {
    private var originalHealthKitService: HealthKitService!
    private var previousDisabledSensors: Any?

    override func setUp() {
        super.setUp()

        originalHealthKitService = Current.healthKitService
        previousDisabledSensors = Current.settingsStore.prefs.object(forKey: "disabledSensors")

        Current.settingsStore.prefs.removeObject(forKey: "disabledSensors")
        Current.healthKitService.isAvailable = { true }
    }

    override func tearDown() {
        restore(previousDisabledSensors, forKey: "disabledSensors")
        Current.healthKitService = originalHealthKitService
        originalHealthKitService = nil
        super.tearDown()
    }

    private func restore(_ value: Any?, forKey key: String) {
        if let value {
            Current.settingsStore.prefs.set(value, forKey: key)
        } else {
            Current.settingsStore.prefs.removeObject(forKey: key)
        }
    }

    @MainActor
    func testRequestHealthAuthorizationRefreshesHealthKitAvailability() async throws {
        var requested = false
        var isAvailable = false
        Current.healthKitService.isAvailable = { isAvailable }
        Current.healthKitService.requestReadAuthorization = {
            requested = true
            isAvailable = true
        }
        let viewModel = SensorListViewModel()

        try await viewModel.requestHealthAuthorization()

        XCTAssertTrue(requested)
        XCTAssertTrue(viewModel.isHealthKitAvailable)
    }

    func testUpdatePermissionsUsesHealthKitAvailability() {
        Current.healthKitService.isAvailable = { false }
        let viewModel = SensorListViewModel()

        viewModel.updatePermissions()

        XCTAssertFalse(viewModel.isHealthKitAvailable)
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
