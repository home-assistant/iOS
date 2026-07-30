import Foundation
import PromiseKit
@testable import Shared
import XCTest

class HealthKitSensorTests: XCTestCase {
    private static let reportedKey = "healthSensorsReported"

    private var request: SensorProviderRequest!
    private var originalDate: (() -> Date)!
    private var originalCalendar: (() -> Calendar)!
    private var originalHealthKitService: HealthKitService!
    private var originalSensors: SensorContainer!
    private var previousReported: Any?

    private let lock = NSLock()
    private var queryCounts = [String: Int]()
    private var queryWindows = [String: (start: Date, end: Date)]()
    private var stubbedValues = [String: Double]()
    private var failingMetricIDs = Set<String>()
    private var observedMetrics = [HealthKitMetric]()
    private var healthKitChangeHandler: HealthKitService.ChangeHandler?
    private var originalDebounceInterval: TimeInterval!
    private var originalMinimumSignalInterval: TimeInterval!

    private var restingHeartRate: HealthKitMetric { .restingHeartRate }
    /// A cumulative metric to pair with the newest-sample resting heart rate.
    private var activeEnergy: HealthKitMetric!

    override func setUpWithError() throws {
        try super.setUpWithError()

        activeEnergy = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_active_energy_burned"))

        originalDate = Current.date
        originalCalendar = Current.calendar
        originalHealthKitService = Current.healthKitService
        originalSensors = Current.sensors
        previousReported = Current.settingsStore.prefs.object(forKey: Self.reportedKey)

        request = .init(
            reason: .trigger("unit-test"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )

        Current.date = { Date(timeIntervalSince1970: 1_000_000) }
        Current.calendar = { Calendar(identifier: .gregorian) }
        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()
        Current.settingsStore.prefs.removeObject(forKey: Self.reportedKey)

        // Enablement is an allowlist, so switch on the two metrics these tests report.
        Current.sensors.setEnabled(true, forUniqueIDs: [activeEnergy.uniqueID, restingHeartRate.uniqueID])

        originalDebounceInterval = HealthKitSensorUpdateSignaler.signalDebounceInterval
        originalMinimumSignalInterval = HealthKitSensorUpdateSignaler.minimumSignalInterval
        HealthKitSensorUpdateSignaler.signalDebounceInterval = 0.05
        HealthKitSensorUpdateSignaler.minimumSignalInterval = 0.05

        stubbedValues = [activeEnergy.uniqueID: 1234, restingHeartRate.uniqueID: 62.4]
        Current.healthKitService.isAvailable = { true }
        Current.healthKitService.queryValue = { [weak self] metric, _, _ in
            guard let self else { return nil }
            recordQuery(metric.uniqueID)
            if isFailing(metric.uniqueID) {
                throw HealthKitService.HealthKitServiceError.unavailable
            }
            return stubbedValue(for: metric.uniqueID)
        }
        Current.healthKitService.setObservedMetrics = { _, _ in }
    }

    override func tearDown() {
        HealthKitSensorUpdateSignaler.signalDebounceInterval = originalDebounceInterval
        HealthKitSensorUpdateSignaler.minimumSignalInterval = originalMinimumSignalInterval
        originalDebounceInterval = nil
        originalMinimumSignalInterval = nil
        SensorEnablementStore.resetForTesting()
        if let previousReported {
            Current.settingsStore.prefs.set(previousReported, forKey: Self.reportedKey)
        } else {
            Current.settingsStore.prefs.removeObject(forKey: Self.reportedKey)
        }
        Current.date = originalDate
        Current.calendar = originalCalendar
        Current.healthKitService = originalHealthKitService
        Current.sensors = originalSensors
        originalDate = nil
        originalCalendar = nil
        originalHealthKitService = nil
        originalSensors = nil
        previousReported = nil
        activeEnergy = nil
        super.tearDown()
    }

    private func recordQuery(_ uniqueID: String) {
        lock.lock()
        defer { lock.unlock() }
        queryCounts[uniqueID, default: 0] += 1
    }

    private func stubbedValue(for uniqueID: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return stubbedValues[uniqueID]
    }

    private func isFailing(_ uniqueID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return failingMetricIDs.contains(uniqueID)
    }

    private func failReads(of uniqueID: String) {
        lock.lock()
        defer { lock.unlock() }
        failingMetricIDs.insert(uniqueID)
    }

    private func recordObservation(of metrics: [HealthKitMetric], onChange: HealthKitService.ChangeHandler? = nil) {
        lock.lock()
        defer { lock.unlock() }
        observedMetrics = metrics
        healthKitChangeHandler = onChange
    }

    private func observedMetricIDs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return observedMetrics.map(\.uniqueID)
    }

    private func notifyHealthKitChange(completion: @escaping () -> Void) {
        lock.lock()
        let handler = healthKitChangeHandler
        lock.unlock()
        handler?(completion)
    }

    private func queryCount(_ uniqueID: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return queryCounts[uniqueID] ?? 0
    }

    private func resetQueryCounts() {
        lock.lock()
        defer { lock.unlock() }
        queryCounts = [:]
    }

    private func recordWindow(start: Date, end: Date, for uniqueID: String) {
        lock.lock()
        defer { lock.unlock() }
        queryWindows[uniqueID] = (start: start, end: end)
    }

    private func window(_ uniqueID: String) -> (start: Date, end: Date)? {
        lock.lock()
        defer { lock.unlock() }
        return queryWindows[uniqueID]
    }

    private func generateSensors() throws -> [WebhookSensor] {
        try hang(HealthKitSensor(request: request).sensors())
    }

    private func sensor(_ metric: HealthKitMetric, in sensors: [WebhookSensor]) -> WebhookSensor? {
        sensors.first(where: { $0.UniqueID == metric.uniqueID })
    }

    func testNothingIsEnabledOrReportedUntilAMetricIsSwitchedOn() throws {
        // Undo the metrics setUp switches on, so this sees a first-launch state.
        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()
        Current.settingsStore.prefs.removeObject(forKey: Self.reportedKey)

        let enabled = HealthKitMetric.all.filter { Current.sensors.isEnabled(uniqueID: $0.uniqueID) }
        XCTAssertTrue(enabled.isEmpty)
        XCTAssertTrue(try generateSensors().isEmpty)
        XCTAssertEqual(queryCount(activeEnergy.uniqueID), 0)
        XCTAssertEqual(queryCount(restingHeartRate.uniqueID), 0)
    }

    func testUnavailableHealthKitReportsNothingAndDoesNotQueryHealthKit() throws {
        Current.healthKitService.isAvailable = { false }

        let sensors = try generateSensors()

        XCTAssertTrue(sensors.isEmpty)
        XCTAssertEqual(queryCount(activeEnergy.uniqueID), 0)
        XCTAssertEqual(queryCount(restingHeartRate.uniqueID), 0)
    }

    func testUnavailableHealthKitStillReportsUnavailableWhenRegistering() throws {
        Current.healthKitService.isAvailable = { false }
        request.reason = .registration

        let sensors = try generateSensors()

        XCTAssertEqual(sensor(activeEnergy, in: sensors)?.State as? String, "unavailable")
        XCTAssertEqual(sensor(restingHeartRate, in: sensors)?.State as? String, "unavailable")
    }

    func testMetricHealthKitRefusesToReadIsLeftOutOfTheUpdate() throws {
        failReads(of: restingHeartRate.uniqueID)

        let sensors = try generateSensors()

        XCTAssertNil(sensor(restingHeartRate, in: sensors))
        XCTAssertEqual(sensor(activeEnergy, in: sensors)?.State as? Int, 1234)
    }

    func testMetricHealthKitRefusesToReadIsReportedUnavailableWhenRegistering() throws {
        failReads(of: restingHeartRate.uniqueID)
        request.reason = .registration

        let sensors = try generateSensors()

        XCTAssertEqual(sensor(restingHeartRate, in: sensors)?.State as? String, "unavailable")
        XCTAssertEqual(sensor(activeEnergy, in: sensors)?.State as? Int, 1234)
    }

    func testEnabledMetricsAreObservedForBackgroundDelivery() throws {
        let observed = expectation(description: "metrics observed")
        Current.healthKitService.setObservedMetrics = { [weak self] metrics, _ in
            self?.recordObservation(of: metrics)
            observed.fulfill()
        }

        _ = try generateSensors()

        wait(for: [observed], timeout: 5)
        XCTAssertEqual(observedMetricIDs().sorted(), [activeEnergy.uniqueID, restingHeartRate.uniqueID].sorted())
    }

    func testDisablingAMetricStopsObservingIt() throws {
        var observed = expectation(description: "metrics observed")
        Current.healthKitService.setObservedMetrics = { [weak self] metrics, _ in
            self?.recordObservation(of: metrics)
            observed.fulfill()
        }

        _ = try generateSensors()
        wait(for: [observed], timeout: 5)

        observed = expectation(description: "observed metrics narrowed")
        Current.sensors.setEnabled(false, forUniqueID: restingHeartRate.uniqueID)

        _ = try generateSensors()

        wait(for: [observed], timeout: 5)
        XCTAssertEqual(observedMetricIDs(), [activeEnergy.uniqueID])
    }

    func testHealthKitReportingNewSamplesSignalsAnUpdate() throws {
        let observed = expectation(description: "metrics observed")
        Current.healthKitService.setObservedMetrics = { [weak self] metrics, onChange in
            self?.recordObservation(of: metrics, onChange: onChange)
            observed.fulfill()
        }
        let signaled = expectation(description: "update signaled")
        request.dependencies.updateSignalHandler = { _ in signaled.fulfill() }

        _ = try generateSensors()
        wait(for: [observed], timeout: 5)

        // HealthKit is only told the change was handled once the update has been asked for.
        let acknowledged = expectation(description: "HealthKit acknowledged")
        notifyHealthKitChange { acknowledged.fulfill() }

        wait(for: [signaled, acknowledged], timeout: 5)
    }

    func testUpdatesAreSpacedOutWhenHealthKitKeepsReportingChanges() throws {
        HealthKitSensorUpdateSignaler.minimumSignalInterval = 0.5

        let observed = expectation(description: "metrics observed")
        Current.healthKitService.setObservedMetrics = { [weak self] metrics, onChange in
            self?.recordObservation(of: metrics, onChange: onChange)
            observed.fulfill()
        }
        var signaled = expectation(description: "first update signaled")
        request.dependencies.updateSignalHandler = { _ in signaled.fulfill() }

        _ = try generateSensors()
        wait(for: [observed], timeout: 5)

        notifyHealthKitChange {}
        wait(for: [signaled], timeout: 5)

        signaled = expectation(description: "second update signaled")
        let secondChange = Date()
        notifyHealthKitChange {}
        wait(for: [signaled], timeout: 5)

        XCTAssertGreaterThan(Date().timeIntervalSince(secondChange), 0.3)
    }

    func testChangesArrivingTogetherAskForASingleUpdate() throws {
        // Long enough that the changes below can't land in windows of their own.
        HealthKitSensorUpdateSignaler.signalDebounceInterval = 1

        let observed = expectation(description: "metrics observed")
        Current.healthKitService.setObservedMetrics = { [weak self] metrics, onChange in
            self?.recordObservation(of: metrics, onChange: onChange)
            observed.fulfill()
        }
        let signaled = expectation(description: "update signaled")
        signaled.assertForOverFulfill = true
        request.dependencies.updateSignalHandler = { _ in signaled.fulfill() }

        _ = try generateSensors()
        wait(for: [observed], timeout: 5)

        let acknowledged = expectation(description: "every change acknowledged")
        acknowledged.expectedFulfillmentCount = 3
        for _ in 0 ..< 3 {
            notifyHealthKitChange { acknowledged.fulfill() }
        }

        wait(for: [signaled, acknowledged], timeout: 5)
    }

    func testSuccessfulDataMapsBothSensors() throws {
        let sensors = try generateSensors()

        let energy = try XCTUnwrap(sensor(activeEnergy, in: sensors))
        XCTAssertEqual(energy.Name, "Active Energy")
        XCTAssertEqual(energy.Icon, "mdi:fire")
        XCTAssertEqual(energy.UnitOfMeasurement, "kcal")
        XCTAssertEqual(energy.State as? Int, 1234)

        let heartRate = try XCTUnwrap(sensor(restingHeartRate, in: sensors))
        XCTAssertEqual(heartRate.Name, "Resting Heart Rate")
        XCTAssertEqual(heartRate.Icon, "mdi:heart-pulse")
        XCTAssertEqual(heartRate.UnitOfMeasurement, "bpm")
        XCTAssertEqual(heartRate.State as? Double, 62.4)
    }

    func testMissingDataReturnsUnavailableRows() throws {
        stubbedValues = [:]

        let sensors = try generateSensors()

        XCTAssertEqual(sensor(activeEnergy, in: sensors)?.State as? String, "unavailable")
        XCTAssertEqual(sensor(restingHeartRate, in: sensors)?.State as? String, "unavailable")
    }

    func testDisabledIndividualSensorDoesNotQueryThatMetric() throws {
        _ = try generateSensors()
        resetQueryCounts()
        Current.sensors.setEnabled(false, forUniqueID: restingHeartRate.uniqueID)

        let sensors = try generateSensors()

        XCTAssertNotNil(sensor(activeEnergy, in: sensors))
        XCTAssertEqual(sensor(restingHeartRate, in: sensors)?.State as? String, "unavailable")
        XCTAssertEqual(queryCount(activeEnergy.uniqueID), 1)
        XCTAssertEqual(queryCount(restingHeartRate.uniqueID), 0)
    }

    func testReEnabledIndividualSensorQueriesThatMetric() throws {
        Current.sensors.setEnabled(false, forUniqueID: restingHeartRate.uniqueID)
        _ = try generateSensors()
        resetQueryCounts()
        request.reason = .trigger(LocationUpdateTrigger.Periodic.rawValue)
        Current.date = { Date(timeIntervalSince1970: 1_000_000 + 60) }
        Current.sensors.setEnabled(true, forUniqueID: restingHeartRate.uniqueID)

        _ = try generateSensors()

        XCTAssertEqual(queryCount(activeEnergy.uniqueID), 1)
        XCTAssertEqual(queryCount(restingHeartRate.uniqueID), 1)
    }

    func testAutomaticUpdateQueriesHealthKit() throws {
        _ = try generateSensors()
        resetQueryCounts()
        request.reason = .trigger(LocationUpdateTrigger.Periodic.rawValue)
        Current.date = { Date(timeIntervalSince1970: 1_000_000 + 60) }

        _ = try generateSensors()

        XCTAssertEqual(queryCount(activeEnergy.uniqueID), 1)
        XCTAssertEqual(queryCount(restingHeartRate.uniqueID), 1)
    }

    func testEnablingAnAdditionalMetricReportsIt() throws {
        let heartRate = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_heart_rate"))
        _ = try generateSensors()
        stubbedValues[heartRate.uniqueID] = 71.6
        Current.sensors.setEnabled(true, forUniqueID: heartRate.uniqueID)

        let sensors = try generateSensors()

        XCTAssertEqual(sensor(heartRate, in: sensors)?.State as? Int, 72)
        XCTAssertEqual(queryCount(heartRate.uniqueID), 1)
    }

    func testMetricsUseTheirOwnQueryWindow() throws {
        let bodyMass = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_body_mass"))
        Current.sensors.setEnabled(true, forUniqueID: bodyMass.uniqueID)
        Current.healthKitService.queryValue = { [weak self] metric, start, end in
            self?.recordWindow(start: start, end: end, for: metric.uniqueID)
            return nil
        }

        _ = try generateSensors()

        let now = Date(timeIntervalSince1970: 1_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let energyWindow = try XCTUnwrap(window(activeEnergy.uniqueID))
        XCTAssertEqual(energyWindow.start, calendar.startOfDay(for: now))
        XCTAssertEqual(energyWindow.end, now)

        let bodyMassWindow = try XCTUnwrap(window(bodyMass.uniqueID))
        XCTAssertEqual(bodyMassWindow.start, calendar.date(byAdding: .day, value: -365, to: now))
    }

    func testIsHealthSensorMatchesEveryCatalogEntry() {
        for metric in HealthKitMetric.all {
            XCTAssertTrue(HealthKitSensor.isHealthSensor(uniqueID: metric.uniqueID), metric.uniqueID)
        }
        XCTAssertFalse(HealthKitSensor.isHealthSensor(uniqueID: "activity"))
        XCTAssertFalse(HealthKitSensor.isHealthSensor(uniqueID: nil))
    }
}
