@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class SensorListViewModelHealthKitTests: XCTestCase {
    private var originalHealthKitService: HealthKitService!
    private var originalSensors: SensorContainer!
    private var previousDisabledSensors: Any?

    override func setUp() {
        super.setUp()

        originalHealthKitService = Current.healthKitService
        originalSensors = Current.sensors
        previousDisabledSensors = Current.settingsStore.prefs.object(forKey: "disabledSensors")

        Current.sensors = SensorContainer()
        Current.settingsStore.prefs.removeObject(forKey: "disabledSensors")
        Current.healthKitService.isAvailable = { true }
    }

    override func tearDown() {
        restore(previousDisabledSensors, forKey: "disabledSensors")
        Current.healthKitService = originalHealthKitService
        Current.sensors = originalSensors
        originalHealthKitService = nil
        originalSensors = nil
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
    func testHealthPermissionIsNotDeterminedUntilItWasRequested() {
        Current.healthKitService.hasRequestedReadAuthorization = { false }
        let viewModel = SensorPermissionsViewModel()

        XCTAssertTrue(viewModel.availablePermissions.contains(.health))
        XCTAssertEqual(viewModel.status(for: .health), .notDetermined)

        Current.healthKitService.hasRequestedReadAuthorization = { true }
        viewModel.update()

        XCTAssertEqual(viewModel.status(for: .health), .requested)
    }

    @MainActor
    func testHealthPermissionIsNotListedWhenHealthKitIsUnavailable() {
        Current.healthKitService.isAvailable = { false }
        let viewModel = SensorPermissionsViewModel()

        viewModel.update()

        XCTAssertFalse(viewModel.availablePermissions.contains(.health))
        XCTAssertFalse(viewModel.statuses.keys.contains(.health))
    }

    @MainActor
    func testNotDeterminedCountOnlyCountsNeverRequestedPermissions() {
        Current.healthKitService.hasRequestedReadAuthorization = { true }
        let viewModel = SensorPermissionsViewModel()

        viewModel.update()

        let expected = viewModel.availablePermissions
            .filter { viewModel.status(for: $0) == .notDetermined }
            .count
        XCTAssertEqual(viewModel.notDeterminedCount, expected)
        XCTAssertFalse(viewModel.availablePermissions.filter { viewModel.status(for: $0) == .notDetermined }
            .contains(.health))
    }

    func testUpdateAllSensorsIncludesHealthSensors() {
        Current.sensors.setEnabled(false, forUniqueID: HealthKitSensor.Metric.steps.uniqueID)
        let viewModel = SensorListViewModelWithoutRefresh()
        viewModel.sensors = [
            WebhookSensor(name: "Health Steps", uniqueID: HealthKitSensor.Metric.steps.uniqueID),
        ]

        viewModel.updateAllSensors(isEnabled: true)

        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: HealthKitSensor.Metric.steps.uniqueID))
    }

    private final class SensorListViewModelWithoutRefresh: SensorListViewModel {
        override func refresh() {}
    }
}
