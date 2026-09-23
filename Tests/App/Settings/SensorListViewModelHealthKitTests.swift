@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class SensorListViewModelHealthKitTests: XCTestCase {
    private static let reportedKey = "healthSensorsReported"

    private var originalHealthKitService: HealthKitService!
    private var originalSensors: SensorContainer!
    private var originalServers: ServerManager!
    private var server: Server!
    private var previousReported: Any?

    override func setUp() {
        super.setUp()

        originalHealthKitService = Current.healthKitService
        originalSensors = Current.sensors
        originalServers = Current.servers
        previousReported = Current.settingsStore.prefs.object(forKey: Self.reportedKey)

        let servers = FakeServerManager()
        server = servers.addFake()
        Current.servers = servers
        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()
        Current.settingsStore.prefs.removeObject(forKey: Self.reportedKey)
        Current.healthKitService.isAvailable = { true }
        // Switching a metric on now asks HealthKit for access, which must not reach the real store.
        Current.healthKitService.requestReadAuthorization = {}
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
        Current.servers = originalServers
        server = nil
        originalHealthKitService = nil
        originalSensors = nil
        originalServers = nil
        previousReported = nil
        super.tearDown()
    }

    // MARK: - Permissions

    @MainActor
    func testNotDeterminedCountOnlyCountsNeverRequestedPermissions() {
        let viewModel = SensorPermissionsViewModel()

        viewModel.update()

        let neverRequested = viewModel.availablePermissions
            .filter { viewModel.status(for: $0) == .notDetermined }
        XCTAssertEqual(viewModel.notDeterminedCount, neverRequested.count)
    }

    func testRequestingAccessWithNothingEnabledFails() async {
        // The real implementation, which `setUp` stubs out so that switching a metric on in the
        // tests below can't reach HealthKit. With nothing enabled it returns before it would.
        Current.healthKitService.requestReadAuthorization = originalHealthKitService.requestReadAuthorization
        // Established explicitly rather than assumed: with a sensor enabled this reaches real
        // HealthKit, which never returns on a headless simulator and hangs the whole suite.
        Current.sensors.setEnabledForAllServers(false, forUniqueIDs: HealthKitMetric.all.map(\.uniqueID))
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

        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: server))
        XCTAssertFalse(Current.sensors.isEnabled(uniqueID: HealthKitMetric.restingHeartRate.uniqueID, for: server))
    }

    // MARK: - Apple Health sensor list

    @MainActor
    func testHealthSensorListStartsWithEverythingDisabled() {
        let viewModel = HealthSensorListViewModel(server: server)

        XCTAssertTrue(viewModel.enabledUniqueIDs.isEmpty)
        XCTAssertFalse(viewModel.areAllEnabled)
    }

    @MainActor
    func testHealthSensorListTogglesIndividualMetrics() throws {
        let viewModel = HealthSensorListViewModel(server: server)
        let metric = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_heart_rate"))

        viewModel.setEnabled(true, for: metric)

        XCTAssertTrue(viewModel.isEnabled(metric))
        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: metric.uniqueID, for: server))

        viewModel.setEnabled(false, for: metric)

        XCTAssertFalse(viewModel.isEnabled(metric))
        XCTAssertFalse(Current.sensors.isEnabled(uniqueID: metric.uniqueID, for: server))
    }

    /// Each category has its own "Enable all", which only covers the metrics it lists.
    @MainActor
    func testHealthSensorListEnablesEverythingInOneCategory() {
        let viewModel = HealthSensorListViewModel(server: server)
        let category = HealthKitMetricCategory.heart
        let inCategory = Set(HealthKitMetric.metrics(in: category).map(\.uniqueID))
        XCTAssertFalse(inCategory.isEmpty)

        viewModel.enableAll(in: category)

        XCTAssertTrue(inCategory.isSubset(of: viewModel.enabledUniqueIDs))
        // The other categories are left alone.
        XCTAssertEqual(viewModel.enabledUniqueIDs, inCategory)
        XCTAssertFalse(viewModel.areAllEnabled)
    }

    @MainActor
    func testHealthSensorListEnablesAndDisablesEverything() {
        let viewModel = HealthSensorListViewModel(server: server)

        viewModel.setAllEnabled(true)
        XCTAssertTrue(viewModel.areAllEnabled)
        XCTAssertEqual(viewModel.enabledUniqueIDs.count, HealthKitMetric.all.count)

        viewModel.setAllEnabled(false)
        XCTAssertTrue(viewModel.enabledUniqueIDs.isEmpty)
    }

    @MainActor
    func testHealthSensorListShowsReportedStates() async throws {
        let viewModel = HealthSensorListViewModel(server: server)
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
        let viewModel = HealthSensorListViewModel(server: server)
        XCTAssertTrue(viewModel.isHealthKitAvailable)

        await viewModel.requestAuthorization()

        XCTAssertTrue(viewModel.showAlert)
        XCTAssertEqual(viewModel.alertMessage, L10n.SettingsSensors.Health.Error.noEnabledSensors)
    }

    @MainActor
    func testHealthSensorListSearchFiltersByName() {
        let viewModel = HealthSensorListViewModel(server: server)

        viewModel.searchTerm = "water"

        XCTAssertTrue(viewModel.isSearching)
        XCTAssertEqual(viewModel.visibleCategories, [.nutrition])
        XCTAssertEqual(viewModel.metrics(in: .nutrition).map(\.uniqueID), ["health_dietary_water"])
    }

    private final class SensorListViewModelWithoutRefresh: SensorListViewModel {
        override func refresh() {}
    }
}
