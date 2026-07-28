import Foundation
import PromiseKit
@testable import Shared
import XCTest

class HealthKitSensorTests: XCTestCase {
    private static let prefsKeys = ["disabledSensors", "healthSensorsSeeded", "healthSensorsReported"]

    private var request: SensorProviderRequest!
    private var originalDate: (() -> Date)!
    private var originalCalendar: (() -> Calendar)!
    private var originalHealthKitService: HealthKitService!
    private var originalSensors: SensorContainer!
    private var previousPrefs: [String: Any?]!

    private let lock = NSLock()
    private var queryCounts = [String: Int]()
    private var queryWindows = [String: (start: Date, end: Date)]()
    private var stubbedValues = [String: Double]()

    private var steps: HealthKitMetric { .steps }
    private var restingHeartRate: HealthKitMetric { .restingHeartRate }

    override func setUp() {
        super.setUp()

        originalDate = Current.date
        originalCalendar = Current.calendar
        originalHealthKitService = Current.healthKitService
        originalSensors = Current.sensors
        previousPrefs = Self.prefsKeys.reduce(into: [String: Any?]()) { result, key in
            result[key] = Current.settingsStore.prefs.object(forKey: key)
        }

        request = .init(
            reason: .trigger("unit-test"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )

        Current.date = { Date(timeIntervalSince1970: 1_000_000) }
        Current.calendar = { Calendar(identifier: .gregorian) }
        Current.sensors = SensorContainer()
        for key in Self.prefsKeys {
            Current.settingsStore.prefs.removeObject(forKey: key)
        }

        stubbedValues = [steps.uniqueID: 1234, restingHeartRate.uniqueID: 62.4]
        Current.healthKitService.isAvailable = { true }
        Current.healthKitService.queryValue = { [weak self] metric, _, _ in
            self?.recordQuery(metric.uniqueID)
            return self?.stubbedValue(for: metric.uniqueID)
        }
    }

    override func tearDown() {
        for (key, value) in previousPrefs {
            if let value {
                Current.settingsStore.prefs.set(value, forKey: key)
            } else {
                Current.settingsStore.prefs.removeObject(forKey: key)
            }
        }
        Current.date = originalDate
        Current.calendar = originalCalendar
        Current.healthKitService = originalHealthKitService
        Current.sensors = originalSensors
        originalDate = nil
        originalCalendar = nil
        originalHealthKitService = nil
        originalSensors = nil
        previousPrefs = nil
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

    func testOnlyTheOriginalMetricsAreEnabledByDefault() throws {
        let sensors = try generateSensors()

        XCTAssertEqual(sensors.compactMap(\.UniqueID), [steps.uniqueID, restingHeartRate.uniqueID])
        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: steps.uniqueID))
        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: restingHeartRate.uniqueID))
        for metric in HealthKitMetric.all where !sensors.contains(where: { $0.UniqueID == metric.uniqueID }) {
            XCTAssertFalse(Current.sensors.isEnabled(uniqueID: metric.uniqueID), metric.uniqueID)
        }
    }

    func testUnavailableHealthKitReturnsUnavailableSensorsAndDoesNotQueryHealthKit() throws {
        Current.healthKitService.isAvailable = { false }

        let sensors = try generateSensors()

        XCTAssertEqual(sensor(steps, in: sensors)?.State as? String, "unavailable")
        XCTAssertEqual(sensor(restingHeartRate, in: sensors)?.State as? String, "unavailable")
        XCTAssertEqual(queryCount(steps.uniqueID), 0)
        XCTAssertEqual(queryCount(restingHeartRate.uniqueID), 0)
    }

    func testSuccessfulDataMapsBothSensors() throws {
        let sensors = try generateSensors()

        let steps = try XCTUnwrap(sensor(self.steps, in: sensors))
        XCTAssertEqual(steps.Name, "Health Steps")
        XCTAssertEqual(steps.Icon, "mdi:walk")
        XCTAssertEqual(steps.UnitOfMeasurement, "steps")
        XCTAssertEqual(steps.State as? Int, 1234)

        let restingHeartRate = try XCTUnwrap(sensor(self.restingHeartRate, in: sensors))
        XCTAssertEqual(restingHeartRate.Name, "Resting Heart Rate")
        XCTAssertEqual(restingHeartRate.Icon, "mdi:heart-pulse")
        XCTAssertEqual(restingHeartRate.UnitOfMeasurement, "bpm")
        XCTAssertEqual(restingHeartRate.State as? Double, 62.4)
    }

    func testMissingDataReturnsUnavailableRows() throws {
        stubbedValues = [:]

        let sensors = try generateSensors()

        XCTAssertEqual(sensor(steps, in: sensors)?.State as? String, "unavailable")
        XCTAssertEqual(sensor(restingHeartRate, in: sensors)?.State as? String, "unavailable")
    }

    func testDisabledIndividualSensorDoesNotQueryThatMetric() throws {
        _ = try generateSensors()
        resetQueryCounts()
        Current.sensors.setEnabled(false, forUniqueID: restingHeartRate.uniqueID)

        let sensors = try generateSensors()

        XCTAssertNotNil(sensor(steps, in: sensors))
        XCTAssertEqual(sensor(restingHeartRate, in: sensors)?.State as? String, "unavailable")
        XCTAssertEqual(queryCount(steps.uniqueID), 1)
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

        XCTAssertEqual(queryCount(steps.uniqueID), 1)
        XCTAssertEqual(queryCount(restingHeartRate.uniqueID), 1)
    }

    func testAutomaticUpdateQueriesHealthKit() throws {
        _ = try generateSensors()
        resetQueryCounts()
        request.reason = .trigger(LocationUpdateTrigger.Periodic.rawValue)
        Current.date = { Date(timeIntervalSince1970: 1_000_000 + 60) }

        _ = try generateSensors()

        XCTAssertEqual(queryCount(steps.uniqueID), 1)
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
        HealthKitSensor.seedInitialEnabledState()
        Current.sensors.setEnabled(true, forUniqueID: bodyMass.uniqueID)
        Current.healthKitService.queryValue = { [weak self] metric, start, end in
            self?.recordWindow(start: start, end: end, for: metric.uniqueID)
            return nil
        }

        _ = try generateSensors()

        let now = Date(timeIntervalSince1970: 1_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let stepsWindow = try XCTUnwrap(window(steps.uniqueID))
        XCTAssertEqual(stepsWindow.start, calendar.startOfDay(for: now))
        XCTAssertEqual(stepsWindow.end, now)

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
