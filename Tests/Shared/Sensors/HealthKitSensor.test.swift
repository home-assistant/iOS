import Foundation
import PromiseKit
@testable import Shared
import Version
import XCTest

class HealthKitSensorTests: XCTestCase {
    private var request: SensorProviderRequest!
    private var stepQueryCount: Int!
    private var restingHeartRateQueryCount: Int!
    private var originalDate: (() -> Date)!
    private var originalCalendar: (() -> Calendar)!
    private var originalHealthKit: AppEnvironment.HealthKit!
    private var previousDisabledSensors: Any?
    private var previousHealthSensorsEnabled: Any?
    private var previousHealthSensorsHaveBeenEnabled: Any?
    private var previousHealthSensorCache: Any?

    override func setUp() {
        super.setUp()

        originalDate = Current.date
        originalCalendar = Current.calendar
        originalHealthKit = Current.healthKit
        previousDisabledSensors = Current.settingsStore.prefs.object(forKey: "disabledSensors")
        previousHealthSensorsEnabled = Current.settingsStore.prefs.object(forKey: "healthSensorsEnabled")
        previousHealthSensorsHaveBeenEnabled = Current.settingsStore.prefs
            .object(forKey: "healthSensorsHaveBeenEnabled")
        previousHealthSensorCache = Current.settingsStore.prefs.object(forKey: "healthSensorCache")

        request = .init(
            reason: .trigger("unit-test"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )

        stepQueryCount = 0
        restingHeartRateQueryCount = 0
        Current.date = { Date(timeIntervalSince1970: 1_000_000) }
        Current.calendar = { Calendar(identifier: .gregorian) }
        Current.settingsStore.prefs.removeObject(forKey: "disabledSensors")
        Current.settingsStore.prefs.removeObject(forKey: "healthSensorsEnabled")
        Current.settingsStore.prefs.removeObject(forKey: "healthSensorsHaveBeenEnabled")
        Current.settingsStore.prefs.removeObject(forKey: "healthSensorCache")
        Current.sensors.setEnabled(true, forUniqueID: HealthKitSensor.Metric.steps.uniqueID)
        Current.sensors.setEnabled(true, forUniqueID: HealthKitSensor.Metric.restingHeartRate.uniqueID)
        Current.healthKit.isAvailable = { true }
        Current.healthKit.queryStepCount = { [weak self] _, _ in
            self?.stepQueryCount += 1
            return .value(1234)
        }
        Current.healthKit.queryLatestRestingHeartRate = { [weak self] _, _ in
            self?.restingHeartRateQueryCount += 1
            return .value(62.4)
        }
    }

    override func tearDown() {
        restore(previousDisabledSensors, forKey: "disabledSensors")
        restore(previousHealthSensorsEnabled, forKey: "healthSensorsEnabled")
        restore(previousHealthSensorsHaveBeenEnabled, forKey: "healthSensorsHaveBeenEnabled")
        restore(previousHealthSensorCache, forKey: "healthSensorCache")
        Current.date = originalDate
        Current.calendar = originalCalendar
        Current.healthKit = originalHealthKit
        originalDate = nil
        originalCalendar = nil
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

    func testMasterOffReturnsNoSensorsWhenNeverEnabled() throws {
        Current.settingsStore.healthSensorsEnabled = false

        let sensors = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertTrue(sensors.isEmpty)
        XCTAssertEqual(stepQueryCount, 0)
        XCTAssertEqual(restingHeartRateQueryCount, 0)
    }

    func testMasterOffReturnsUnavailableSensorsAndDoesNotQueryHealthKit() throws {
        Current.settingsStore.healthSensorsHaveBeenEnabled = true
        Current.settingsStore.healthSensorsEnabled = false

        let sensors = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertEqual(
            sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.steps.uniqueID })?.State as? String,
            "unavailable"
        )
        XCTAssertEqual(
            sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.restingHeartRate.uniqueID })?.State as? String,
            "unavailable"
        )
        XCTAssertEqual(stepQueryCount, 0)
        XCTAssertEqual(restingHeartRateQueryCount, 0)
    }

    func testUnavailableHealthKitReturnsUnavailableSensorsAndDoesNotQueryHealthKit() throws {
        Current.settingsStore.healthSensorsEnabled = true
        Current.healthKit.isAvailable = { false }

        let sensors = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertEqual(
            sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.steps.uniqueID })?.State as? String,
            "unavailable"
        )
        XCTAssertEqual(
            sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.restingHeartRate.uniqueID })?.State as? String,
            "unavailable"
        )
        XCTAssertEqual(stepQueryCount, 0)
        XCTAssertEqual(restingHeartRateQueryCount, 0)
    }

    func testSuccessfulDataMapsBothSensors() throws {
        Current.settingsStore.healthSensorsEnabled = true

        let sensors = try hang(HealthKitSensor(request: request).sensors())

        let steps = try XCTUnwrap(sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.steps.uniqueID }))
        XCTAssertEqual(steps.Name, "Health Steps")
        XCTAssertEqual(steps.Icon, "mdi:walk")
        XCTAssertEqual(steps.UnitOfMeasurement, "steps")
        XCTAssertEqual(steps.State as? Int, 1234)

        let restingHeartRate = try XCTUnwrap(sensors.first(
            where: { $0.UniqueID == HealthKitSensor.Metric.restingHeartRate.uniqueID }
        ))
        XCTAssertEqual(restingHeartRate.Name, "Resting Heart Rate")
        XCTAssertEqual(restingHeartRate.Icon, "mdi:heart-pulse")
        XCTAssertEqual(restingHeartRate.UnitOfMeasurement, "bpm")
        XCTAssertEqual(restingHeartRate.State as? Double, 62.4)
    }

    func testMissingDataReturnsUnavailableRows() throws {
        Current.settingsStore.healthSensorsEnabled = true
        Current.healthKit.queryStepCount = { [weak self] _, _ in
            self?.stepQueryCount += 1
            return .value(nil)
        }
        Current.healthKit.queryLatestRestingHeartRate = { [weak self] _, _ in
            self?.restingHeartRateQueryCount += 1
            return .value(nil)
        }

        let sensors = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertEqual(
            sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.steps.uniqueID })?.State as? String,
            "unavailable"
        )
        XCTAssertEqual(
            sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.restingHeartRate.uniqueID })?.State as? String,
            "unavailable"
        )
    }

    func testDisabledIndividualSensorDoesNotQueryThatMetric() throws {
        Current.settingsStore.healthSensorsEnabled = true
        Current.sensors.setEnabled(false, forUniqueID: HealthKitSensor.Metric.restingHeartRate.uniqueID)

        let sensors = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertNotNil(sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.steps.uniqueID }))
        XCTAssertEqual(
            sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.restingHeartRate.uniqueID })?.State as? String,
            "unavailable"
        )
        XCTAssertEqual(stepQueryCount, 1)
        XCTAssertEqual(restingHeartRateQueryCount, 0)
    }

    func testReEnabledIndividualSensorRefreshesMissingCachedMetric() throws {
        Current.settingsStore.healthSensorsEnabled = true
        Current.sensors.setEnabled(false, forUniqueID: HealthKitSensor.Metric.restingHeartRate.uniqueID)
        _ = try hang(HealthKitSensor(request: request).sensors())
        stepQueryCount = 0
        restingHeartRateQueryCount = 0
        request.reason = .trigger(LocationUpdateTrigger.Periodic.rawValue)
        Current.date = { Date(timeIntervalSince1970: 1_000_000 + 60) }
        Current.sensors.setEnabled(true, forUniqueID: HealthKitSensor.Metric.restingHeartRate.uniqueID)

        _ = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertEqual(stepQueryCount, 1)
        XCTAssertEqual(restingHeartRateQueryCount, 1)
    }

    func testAutomaticUpdateWithinCacheWindowUsesCachedValues() throws {
        Current.settingsStore.healthSensorsEnabled = true
        _ = try hang(HealthKitSensor(request: request).sensors())
        stepQueryCount = 0
        restingHeartRateQueryCount = 0
        request.reason = .trigger(LocationUpdateTrigger.Periodic.rawValue)
        Current.date = { Date(timeIntervalSince1970: 1_000_000 + 60) }

        let sensors = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertEqual(
            sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.steps.uniqueID })?.State as? Int,
            1234
        )
        XCTAssertEqual(
            sensors.first(where: { $0.UniqueID == HealthKitSensor.Metric.restingHeartRate.uniqueID })?.State as? Double,
            62.4
        )
        XCTAssertEqual(stepQueryCount, 0)
        XCTAssertEqual(restingHeartRateQueryCount, 0)
    }

    func testAutomaticUpdateAfterCacheWindowRefreshesHealthKit() throws {
        Current.settingsStore.healthSensorsEnabled = true
        _ = try hang(HealthKitSensor(request: request).sensors())
        stepQueryCount = 0
        restingHeartRateQueryCount = 0
        request.reason = .trigger(LocationUpdateTrigger.Periodic.rawValue)
        Current.date = { Date(timeIntervalSince1970: 1_000_000 + 901) }

        _ = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertEqual(stepQueryCount, 1)
        XCTAssertEqual(restingHeartRateQueryCount, 1)
    }

    func testManualUpdateBypassesCache() throws {
        Current.settingsStore.healthSensorsEnabled = true
        _ = try hang(HealthKitSensor(request: request).sensors())
        stepQueryCount = 0
        restingHeartRateQueryCount = 0
        request.reason = .trigger(LocationUpdateTrigger.Manual.rawValue)
        Current.date = { Date(timeIntervalSince1970: 1_000_000 + 60) }

        _ = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertEqual(stepQueryCount, 1)
        XCTAssertEqual(restingHeartRateQueryCount, 1)
    }
}
