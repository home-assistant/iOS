@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class SensorListViewModelHealthKitTests: XCTestCase {
    private var originalHealthKitService: HealthKitService!
    private var originalSensors: SensorContainer!

    override func setUp() {
        super.setUp()

        originalHealthKitService = Current.healthKitService
        originalSensors = Current.sensors

        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()
        Current.healthKitService.isAvailable = { true }
    }

    override func tearDown() {
        SensorEnablementStore.resetForTesting()
        Current.healthKitService = originalHealthKitService
        Current.sensors = originalSensors
        originalHealthKitService = nil
        originalSensors = nil
        super.tearDown()
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

        let neverRequested = viewModel.availablePermissions
            .filter { viewModel.status(for: $0) == .notDetermined }
        XCTAssertEqual(viewModel.notDeterminedCount, neverRequested.count)
        XCTAssertFalse(neverRequested.contains(.health))
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
