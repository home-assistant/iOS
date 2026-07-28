@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class SensorListViewModelHealthKitTests: XCTestCase {
    private static let prefsKeys = ["disabledSensors", "healthSensorsSeeded", "healthSensorsReported"]

    private var originalHealthKitService: HealthKitService!
    private var originalSensors: SensorContainer!
    private var previousPrefs: [String: Any?]!

    override func setUp() {
        super.setUp()

        originalHealthKitService = Current.healthKitService
        originalSensors = Current.sensors
        previousPrefs = Self.prefsKeys.reduce(into: [String: Any?]()) { result, key in
            result[key] = Current.settingsStore.prefs.object(forKey: key)
        }

        Current.sensors = SensorContainer()
        for key in Self.prefsKeys {
            Current.settingsStore.prefs.removeObject(forKey: key)
        }
        Current.healthKitService.isAvailable = { true }
    }

    override func tearDown() {
        for (key, value) in previousPrefs {
            if let value {
                Current.settingsStore.prefs.set(value, forKey: key)
            } else {
                Current.settingsStore.prefs.removeObject(forKey: key)
            }
        }
        Current.healthKitService = originalHealthKitService
        Current.sensors = originalSensors
        originalHealthKitService = nil
        originalSensors = nil
        previousPrefs = nil
        super.tearDown()
    }

    func testUpdatePermissionsUsesHealthKitAvailability() {
        Current.healthKitService.isAvailable = { false }
        let viewModel = SensorListViewModel()

        viewModel.updatePermissions()

        XCTAssertFalse(viewModel.isHealthKitAvailable)
    }

    func testEnabledHealthSensorCountReflectsTheSeededDefaults() {
        let viewModel = SensorListViewModel()

        viewModel.updatePermissions()

        XCTAssertEqual(viewModel.enabledHealthSensorCount, 2)
    }

    func testListedSensorsExcludesHealthSensors() {
        let viewModel = SensorListViewModelWithoutRefresh()
        viewModel.sensors = [
            WebhookSensor(name: "Health Steps", uniqueID: HealthKitMetric.steps.uniqueID),
            WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue),
        ]

        XCTAssertEqual(viewModel.listedSensors.compactMap(\.UniqueID), [WebhookSensorId.activity.rawValue])
    }

    func testUpdateAllSensorsLeavesHealthSensorsAlone() {
        Current.sensors.setEnabled(false, forUniqueID: HealthKitMetric.steps.uniqueID)
        Current.sensors.setEnabled(false, forUniqueID: WebhookSensorId.activity.rawValue)
        let viewModel = SensorListViewModelWithoutRefresh()
        viewModel.sensors = [
            WebhookSensor(name: "Health Steps", uniqueID: HealthKitMetric.steps.uniqueID),
            WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue),
        ]

        viewModel.updateAllSensors(isEnabled: true)

        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: WebhookSensorId.activity.rawValue))
        XCTAssertFalse(Current.sensors.isEnabled(uniqueID: HealthKitMetric.steps.uniqueID))
    }

    @MainActor
    func testHealthSensorListSeedsNewMetricsAsDisabled() {
        let viewModel = HealthSensorListViewModel()

        XCTAssertEqual(viewModel.enabledUniqueIDs, [
            HealthKitMetric.steps.uniqueID,
            HealthKitMetric.restingHeartRate.uniqueID,
        ])
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
            name: "Health Steps",
            uniqueID: HealthKitMetric.steps.uniqueID,
            state: 1234,
            unit: "steps"
        )

        viewModel.sensorContainer(Current.sensors, didUpdate: .init(sensors: .value([sensor])))

        for _ in 0 ..< 100 where viewModel.stateDescriptions.isEmpty {
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        XCTAssertEqual(viewModel.stateDescription(for: .steps), "1234 steps")
    }

    @MainActor
    func testHealthSensorListSearchFiltersByName() {
        let viewModel = HealthSensorListViewModel()

        viewModel.searchTerm = "caffeine"

        XCTAssertEqual(viewModel.visibleCategories, [.nutrition])
        XCTAssertEqual(viewModel.metrics(in: .nutrition).map(\.uniqueID), ["health_dietary_caffeine"])
    }

    @MainActor
    func testRequestingAccessWithNothingEnabledSurfacesAnError() async {
        Current.sensors.setEnabled(false, forUniqueIDs: HealthKitMetric.all.map(\.uniqueID))
        Current.healthKitService.requestReadAuthorization = {
            throw HealthKitService.HealthKitServiceError.noEnabledSensors
        }
        let viewModel = HealthSensorListViewModel()

        await viewModel.requestAuthorization()

        XCTAssertTrue(viewModel.showAlert)
        XCTAssertEqual(viewModel.alertMessage, L10n.SettingsSensors.Health.Error.noEnabledSensors)
    }

    @MainActor
    func testRequestingAccessRefreshesAvailability() async {
        var requested = false
        var isAvailable = false
        Current.healthKitService.isAvailable = { isAvailable }
        Current.healthKitService.requestReadAuthorization = {
            requested = true
            isAvailable = true
        }
        let viewModel = HealthSensorListViewModel()

        await viewModel.requestAuthorization()

        XCTAssertTrue(requested)
        XCTAssertTrue(viewModel.isHealthKitAvailable)
        XCTAssertFalse(viewModel.showAlert)
    }

    private final class SensorListViewModelWithoutRefresh: SensorListViewModel {
        override func refresh() {}
    }
}
