import Foundation
import HealthKit
@testable import Shared
import XCTest

/// A summary of a chosen day. HealthKit derives the day itself and offers no way to set it.
private final class DatedActivitySummary: HKActivitySummary {
    var day = DateComponents()

    override func dateComponents(for calendar: Calendar) -> DateComponents {
        day
    }
}

class HealthKitActivityRingTests: XCTestCase {
    private var calendar: Calendar!
    private var originalCalendar: (() -> Calendar)!
    private var originalHealthKitService: HealthKitService!
    private var requestedDays: (start: DateComponents, end: DateComponents)?

    override func setUpWithError() throws {
        try super.setUpWithError()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        calendar = utc
        originalCalendar = Current.calendar
        originalHealthKitService = Current.healthKitService
        Current.calendar = { utc }
    }

    override func tearDown() {
        Current.calendar = originalCalendar
        Current.healthKitService = originalHealthKitService
        originalCalendar = nil
        originalHealthKitService = nil
        requestedDays = nil
        calendar = nil
        super.tearDown()
    }

    private func day(_ day: Int) -> DateComponents {
        DateComponents(calendar: calendar, era: 1, year: 2026, month: 3, day: day)
    }

    private func summary(on day: DateComponents, moveGoal: Double) -> HKActivitySummary {
        let summary = DatedActivitySummary()
        summary.day = day
        summary.activityMoveMode = .activeEnergy
        summary.activeEnergyBurnedGoal = HKQuantity(unit: .kilocalorie(), doubleValue: moveGoal)
        return summary
    }

    private func summary(
        move: Double = 420,
        moveGoal: Double = 600,
        exercise: Double = 25,
        exerciseGoal: Double? = 30,
        stand: Double = 7,
        standGoal: Double? = 12
    ) -> HKActivitySummary {
        let summary = HKActivitySummary()
        summary.activityMoveMode = .activeEnergy
        summary.activeEnergyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: move)
        summary.activeEnergyBurnedGoal = HKQuantity(unit: .kilocalorie(), doubleValue: moveGoal)
        summary.appleExerciseTime = HKQuantity(unit: .minute(), doubleValue: exercise)
        summary.exerciseTimeGoal = exerciseGoal.map { HKQuantity(unit: .minute(), doubleValue: $0) }
        summary.appleStandHours = HKQuantity(unit: .count(), doubleValue: stand)
        summary.standHoursGoal = standGoal.map { HKQuantity(unit: .count(), doubleValue: $0) }
        return summary
    }

    func testIdentifierIsTheActivitySummaryType() {
        XCTAssertEqual(HealthKitActivitySummaryField.identifier, HKObjectType.activitySummaryType().identifier)
    }

    func testProgressAndGoalAreReadInTheRequestedUnit() {
        let summary = summary()

        XCTAssertEqual(HealthKitActivitySummaryField.progress(.move).value(in: summary, unit: .kilocalorie()), 420)
        XCTAssertEqual(HealthKitActivitySummaryField.goal(.move).value(in: summary, unit: .kilocalorie()), 600)
        XCTAssertEqual(HealthKitActivitySummaryField.progress(.exercise).value(in: summary, unit: .minute()), 25)
        XCTAssertEqual(HealthKitActivitySummaryField.goal(.exercise).value(in: summary, unit: .minute()), 30)
        XCTAssertEqual(HealthKitActivitySummaryField.progress(.stand).value(in: summary, unit: .count()), 7)
        XCTAssertEqual(HealthKitActivitySummaryField.goal(.stand).value(in: summary, unit: .count()), 12)

        // Units are converted rather than assumed, so a caller asking in another unit of the same
        // dimension gets a correct answer.
        XCTAssertEqual(HealthKitActivitySummaryField.goal(.exercise).value(in: summary, unit: .second()), 1800)
    }

    func testRingWithoutAGoalIsUnavailableRatherThanZero() {
        // What a summary looks like without an Apple Watch: the Move ring is tracked, the others have
        // no goal at all.
        let summary = summary(exercise: 0, exerciseGoal: nil, stand: 0, standGoal: nil)

        XCTAssertEqual(HealthKitActivitySummaryField.progress(.move).value(in: summary, unit: .kilocalorie()), 420)
        XCTAssertEqual(HealthKitActivitySummaryField.goal(.move).value(in: summary, unit: .kilocalorie()), 600)
        XCTAssertNil(HealthKitActivitySummaryField.progress(.exercise).value(in: summary, unit: .minute()))
        XCTAssertNil(HealthKitActivitySummaryField.goal(.exercise).value(in: summary, unit: .minute()))
        XCTAssertNil(HealthKitActivitySummaryField.progress(.stand).value(in: summary, unit: .count()))
        XCTAssertNil(HealthKitActivitySummaryField.goal(.stand).value(in: summary, unit: .count()))
    }

    func testMoveRingMeasuringMoveTimeIsUnavailableInKilocalories() {
        // In move time mode the energy fields can still carry numbers, but they aren't the ring, so
        // neither sensor claims to be. The other rings are unaffected.
        let summary = summary(move: 310, moveGoal: 500)
        summary.activityMoveMode = .appleMoveTime

        XCTAssertNil(HealthKitActivitySummaryField.progress(.move).value(in: summary, unit: .kilocalorie()))
        XCTAssertNil(HealthKitActivitySummaryField.goal(.move).value(in: summary, unit: .kilocalorie()))
        XCTAssertEqual(HealthKitActivitySummaryField.progress(.exercise).value(in: summary, unit: .minute()), 25)
    }

    func testMoveRingMeasuringEnergyWithoutAGoalIsUnavailable() {
        let summary = summary(move: 310, moveGoal: 0)
        summary.activityMoveMode = .activeEnergy

        XCTAssertNil(HealthKitActivitySummaryField.progress(.move).value(in: summary, unit: .kilocalorie()))
        XCTAssertNil(HealthKitActivitySummaryField.goal(.move).value(in: summary, unit: .kilocalorie()))
    }

    func testZeroProgressTowardsASetGoalIsReported() {
        let summary = summary(stand: 0)

        XCTAssertEqual(HealthKitActivitySummaryField.progress(.stand).value(in: summary, unit: .count()), 0)
        XCTAssertEqual(HealthKitActivitySummaryField.goal(.stand).value(in: summary, unit: .count()), 12)
    }

    func testUnitOfAnotherDimensionIsRefused() {
        let summary = summary()

        XCTAssertNil(HealthKitActivitySummaryField.progress(.move).value(in: summary, unit: .minute()))
        XCTAssertNil(HealthKitActivitySummaryField.goal(.stand).value(in: summary, unit: .kilocalorie()))
    }

    func testEachRingIsMovedByItsOwnSampleType() {
        XCTAssertEqual(
            HealthKitActivityRing.move.progressSampleType.identifier,
            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue
        )
        XCTAssertEqual(
            HealthKitActivityRing.exercise.progressSampleType.identifier,
            HKQuantityTypeIdentifier.appleExerciseTime.rawValue
        )
        XCTAssertEqual(
            HealthKitActivityRing.stand.progressSampleType.identifier,
            HKCategoryTypeIdentifier.appleStandHour.rawValue
        )
    }

    func testOnlyProgressIsObservedForBackgroundDelivery() {
        // Changing a goal in Fitness writes no sample, so a goal has nothing to observe.
        XCTAssertEqual(
            HealthKitActivitySummaryField.progress(.stand).observedSampleTypes.map(\.identifier),
            [HKCategoryTypeIdentifier.appleStandHour.rawValue]
        )
        for ring in HealthKitActivityRing.allCases {
            XCTAssertTrue(HealthKitActivitySummaryField.goal(ring).observedSampleTypes.isEmpty, ring.rawValue)
        }
    }

    func testRingMetricsAskForTheSummaryTypeAndObserveOnlyProgress() throws {
        let moveGoal = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_active_energy_burned_goal"))
        let standHours = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_apple_stand_hours"))
        let summaryType = HKObjectType.activitySummaryType()
        let standHourType = HKCategoryType(.appleStandHour)

        // A goal alone asks for nothing but the summary: no sample type the user didn't choose lands on
        // the permission sheet, and nothing wakes the app to re-read a constant.
        XCTAssertEqual(HealthKitService.readTypes(for: [moveGoal]), [summaryType])
        XCTAssertTrue(HealthKitService.observableTypes(for: [moveGoal]).isEmpty)

        XCTAssertEqual(HealthKitService.readTypes(for: [standHours]), [standHourType, summaryType])
        XCTAssertEqual(HealthKitService.observableTypes(for: [standHours]), [standHourType])
    }

    func testReadTypesDedupeSharedTypes() throws {
        let sleepDuration = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_sleep_duration"))
        let inBed = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_sleep_in_bed"))
        let standHours = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_apple_stand_hours"))
        let standGoal = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_apple_stand_hours_goal"))

        let types = HealthKitService.readTypes(for: [sleepDuration, inBed, standHours, standGoal])

        XCTAssertEqual(
            Set(types.map(\.identifier)),
            [
                HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
                HKCategoryTypeIdentifier.appleStandHour.rawValue,
                HKObjectType.activitySummaryType().identifier,
            ]
        )
    }

    func testOnlySampleTypesAreObserved() throws {
        let steps = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_steps"))
        let sleepDuration = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_sleep_duration"))
        // What a catalog typo looks like: the summary type is read, but it isn't a sample type.
        let typo = HealthKitMetric(
            uniqueID: "health_typo",
            identifier: HealthKitActivitySummaryField.identifier,
            name: "Typo",
            icon: "mdi:bug",
            unit: nil,
            queryUnit: .count,
            aggregation: .mostRecent,
            category: .activity
        )

        XCTAssertEqual(
            HealthKitService.observableTypes(for: [steps, sleepDuration]).map(\.identifier),
            [HKQuantityTypeIdentifier.stepCount.rawValue, HKCategoryTypeIdentifier.sleepAnalysis.rawValue]
        )
        XCTAssertTrue(HealthKitService.observableTypes(for: [typo]).isEmpty)
        XCTAssertTrue(HealthKitService.readTypes(for: [typo]).isEmpty)
    }

    func testLatestSummaryIsPickedWhateverOrderHealthKitUses() {
        let older = summary(on: day(9), moveGoal: 500)
        let newer = summary(on: day(10), moveGoal: 610)

        XCTAssertIdentical(HealthKitService.latestActivitySummary(in: [older, newer], calendar: calendar), newer)
        XCTAssertIdentical(HealthKitService.latestActivitySummary(in: [newer, older], calendar: calendar), newer)
        XCTAssertNil(HealthKitService.latestActivitySummary(in: [], calendar: calendar))
    }

    func testGoalIsReadFromTheLatestSummaryOfTheWindow() async throws {
        let moveGoal = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_active_energy_burned_goal"))
        let start = try XCTUnwrap(calendar.date(from: day(4)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 17)))
        Current.healthKitService.activitySummaries = { [self] start, end in
            requestedDays = (start, end)
            return [summary(on: day(9), moveGoal: 500), summary(on: day(10), moveGoal: 610)]
        }

        let value = try await Current.healthKitService.queryValue(moveGoal, start, end)

        XCTAssertEqual(value, 610)
        // The query spans the local calendar days of the window, not its instants.
        XCTAssertEqual(requestedDays?.start, day(4))
        XCTAssertEqual(requestedDays?.end, day(10))
    }

    func testGoalIsUnavailableWhenNoDayOfTheWindowHasASummary() async throws {
        let moveGoal = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_active_energy_burned_goal"))
        Current.healthKitService.activitySummaries = { _, _ in [] }

        let value = try await Current.healthKitService.queryValue(moveGoal, Date(), Date())

        XCTAssertNil(value)
    }

    func testActivitySummaryDayIsTheLocalCalendarDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        // 03:30 UTC on 10 March is still 22:30 on 9 March in New York.
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2024-03-10T03:30:00Z"))

        let day = HealthKitService.activitySummaryDay(containing: date, calendar: calendar)

        XCTAssertEqual(day.era, 1)
        XCTAssertEqual(day.year, 2024)
        XCTAssertEqual(day.month, 3)
        XCTAssertEqual(day.day, 9)
        XCTAssertNil(day.hour)
        XCTAssertEqual(day.calendar?.identifier, .gregorian)
        XCTAssertEqual(day.calendar?.timeZone.identifier, "America/New_York")
    }
}
