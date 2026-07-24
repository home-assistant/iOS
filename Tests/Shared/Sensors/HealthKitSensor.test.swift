import Foundation
import PromiseKit
@testable import Shared
import XCTest

class HealthKitSensorTests: XCTestCase {
    private var request: SensorProviderRequest!
    private var stepQueryCount: Int!
    private var restingHeartRateQueryCount: Int!
    private var originalDate: (() -> Date)!
    private var originalCalendar: (() -> Calendar)!
    private var originalHealthKitService: HealthKitService!
    private var previousDisabledSensors: Any?

    override func setUp() {
        super.setUp()

        originalDate = Current.date
        originalCalendar = Current.calendar
        originalHealthKitService = Current.healthKitService
        previousDisabledSensors = Current.settingsStore.prefs.object(forKey: "disabledSensors")

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
        Current.sensors.setEnabled(true, forUniqueID: HealthKitSensor.Metric.steps.uniqueID)
        Current.sensors.setEnabled(true, forUniqueID: HealthKitSensor.Metric.restingHeartRate.uniqueID)
        Current.healthKitService.isAvailable = { true }
        Current.healthKitService.queryStepCount = { [weak self] _, _ in
            self?.stepQueryCount += 1
            return 1234
        }
        Current.healthKitService.queryLatestRestingHeartRate = { [weak self] _, _ in
            self?.restingHeartRateQueryCount += 1
            return 62.4
        }
    }

    override func tearDown() {
        restore(previousDisabledSensors, forKey: "disabledSensors")
        Current.date = originalDate
        Current.calendar = originalCalendar
        Current.healthKitService = originalHealthKitService
        originalDate = nil
        originalCalendar = nil
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

    func testUnavailableHealthKitReturnsUnavailableSensorsAndDoesNotQueryHealthKit() throws {
        Current.healthKitService.isAvailable = { false }

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
        Current.healthKitService.queryStepCount = { [weak self] _, _ in
            self?.stepQueryCount += 1
            return nil
        }
        Current.healthKitService.queryLatestRestingHeartRate = { [weak self] _, _ in
            self?.restingHeartRateQueryCount += 1
            return nil
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

    func testReEnabledIndividualSensorQueriesThatMetric() throws {
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

    func testAutomaticUpdateQueriesHealthKit() throws {
        _ = try hang(HealthKitSensor(request: request).sensors())
        stepQueryCount = 0
        restingHeartRateQueryCount = 0
        request.reason = .trigger(LocationUpdateTrigger.Periodic.rawValue)
        Current.date = { Date(timeIntervalSince1970: 1_000_000 + 60) }

        _ = try hang(HealthKitSensor(request: request).sensors())

        XCTAssertEqual(stepQueryCount, 1)
        XCTAssertEqual(restingHeartRateQueryCount, 1)
    }
}
