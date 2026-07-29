@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class SensorListViewModelHealthKitTests: XCTestCase {
    private static let reportedKey = "healthSensorsReported"

    private var originalHealthKitService: HealthKitService!
    private var originalSensors: SensorContainer!
    private var previousReported: Any?

    override func setUp() {
        super.setUp()

        originalHealthKitService = Current.healthKitService
        originalSensors = Current.sensors
        previousReported = Current.settingsStore.prefs.object(forKey: Self.reportedKey)

        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()
        Current.settingsStore.prefs.removeObject(forKey: Self.reportedKey)
        Current.healthKitService.isAvailable = { true }
    }

    override func tearDown() {
        SensorEnablementStore.resetForTesting()
        if let previousReported {
            Current.settingsStore.prefs.set(previousReported, forKey: Self.reportedKey)
        } else {
            Current.settingsStore.prefs.removeObject(forKey: Self.reportedKey)
        }
        Current.healthKitService = originalHealthKitService
        Current.sensors = originalSensors
        originalHealthKitService = nil
        originalSensors = nil
        previousReported = nil
        super.tearDown()
    }

    // MARK: - Permissions

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

    func testHealthPermissionIsNotChangedInSystemSettings() {
        XCTAssertFalse(SensorPermission.health.isChangedInSystemSettings)
        XCTAssertTrue(SensorPermission.motion.isChangedInSystemSettings)
        XCTAssertTrue(SensorPermission.focus.isChangedInSystemSettings)
    }

    /// Apple Health isn't listed on the app's page in system settings, so a second tap has to ask
    /// HealthKit again — that is what surfaces the sensors enabled since the last request.
    @MainActor
    func testTappingHealthAgainRequestsRatherThanOpeningSettings() async throws {
        Current.healthKitService.hasRequestedReadAuthorization = { true }
        var requested = false
        Current.healthKitService.requestReadAuthorization = { requested = true }
        let viewModel = SensorPermissionsViewModel()
        XCTAssertEqual(viewModel.status(for: .health), .requested)

        viewModel.handleTap(on: .health)

        for _ in 0 ..< 100 where !requested {
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        XCTAssertTrue(requested)
    }

    func testRequestingAccessWithNothingEnabledFails() async {
        var thrown: Error?

        do {
            try await Current.healthKitService.requestReadAuthorization()
        } catch {
            thrown = error
        }

        XCTAssertEqual(thrown as? HealthKitService.HealthKitServiceError, .noEnabledSensors)
    }

    // MARK: - Sensor list

    func testNoHealthSensorIsEnabledOnAFreshInstall() {
        let viewModel = SensorListViewModelWithoutRefresh()

        XCTAssertEqual(viewModel.enabledHealthSensorCount, 0)
    }

    func testHealthSensorsAreExcludedFromTheMainList() {
        let sensors = [
            WebhookSensor(name: "Resting Heart Rate", uniqueID: HealthKitMetric.restingHeartRate.uniqueID),
            WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue),
        ]

        let listed = SensorListViewModel.excludingHealthSensors(sensors)

        XCTAssertEqual(listed.compactMap(\.UniqueID), [WebhookSensorId.activity.rawValue])
    }

    func testUpdateAllSensorsLeavesHealthSensorsAlone() {
        let viewModel = SensorListViewModelWithoutRefresh()
        viewModel.sensors = [WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)]

        viewModel.updateAllSensors(isEnabled: true)

        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: WebhookSensorId.activity.rawValue))
        XCTAssertFalse(Current.sensors.isEnabled(uniqueID: HealthKitMetric.restingHeartRate.uniqueID))
    }

    // MARK: - Apple Health sensor list

    @MainActor
    func testHealthSensorListStartsWithEverythingDisabled() {
        let viewModel = HealthSensorListViewModel()

        XCTAssertTrue(viewModel.enabledUniqueIDs.isEmpty)
        XCTAssertFalse(viewModel.areAllEnabled)
    }

    @MainActor
    func testHealthSensorListTogglesIndividualMetrics() throws {
        let viewModel = HealthSensorListViewModel()
        let metric = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_heart_rate"))

        viewModel.setEnabled(true, for: metric)

        XCTAssertTrue(viewModel.isEnabled(metric))
        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: metric.uniqueID))

        viewModel.setEnabled(false, for: metric)

        XCTAssertFalse(viewModel.isEnabled(metric))
        XCTAssertFalse(Current.sensors.isEnabled(uniqueID: metric.uniqueID))
    }

    @MainActor
    func testHealthSensorListEnablesAndDisablesEverything() {
        let viewModel = HealthSensorListViewModel()

        viewModel.setAllEnabled(true)
        XCTAssertTrue(viewModel.areAllEnabled)
        XCTAssertEqual(viewModel.enabledUniqueIDs.count, HealthKitMetric.all.count)

        viewModel.setAllEnabled(false)
        XCTAssertTrue(viewModel.enabledUniqueIDs.isEmpty)
    }

    @MainActor
    func testHealthSensorListShowsReportedStates() async throws {
        let viewModel = HealthSensorListViewModel()
        let sensor = WebhookSensor(
            name: "Resting Heart Rate",
            uniqueID: HealthKitMetric.restingHeartRate.uniqueID,
            state: 62,
            unit: "bpm"
        )

        viewModel.sensorContainer(Current.sensors, didUpdate: .init(sensors: .value([sensor])))

        for _ in 0 ..< 100 where viewModel.stateDescriptions.isEmpty {
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        XCTAssertEqual(viewModel.stateDescription(for: .restingHeartRate), "62 bpm")
    }

    @MainActor
    func testHealthSensorListRequestsAccessAndSurfacesFailures() async {
        Current.healthKitService.requestReadAuthorization = {
            throw HealthKitService.HealthKitServiceError.noEnabledSensors
        }
        let viewModel = HealthSensorListViewModel()
        XCTAssertTrue(viewModel.isHealthKitAvailable)

        await viewModel.requestAuthorization()

        XCTAssertTrue(viewModel.showAlert)
        XCTAssertEqual(viewModel.alertMessage, L10n.SettingsSensors.Health.Error.noEnabledSensors)
    }

    @MainActor
    func testHealthSensorListSearchFiltersByName() {
        let viewModel = HealthSensorListViewModel()

        viewModel.searchTerm = "water"

        XCTAssertTrue(viewModel.isSearching)
        XCTAssertEqual(viewModel.visibleCategories, [.nutrition])
        XCTAssertEqual(viewModel.metrics(in: .nutrition).map(\.uniqueID), ["health_dietary_water"])
    }

    private final class SensorListViewModelWithoutRefresh: SensorListViewModel {
        override func refresh() {}
    }
}
