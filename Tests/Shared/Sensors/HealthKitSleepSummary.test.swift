import Foundation
@testable import Shared
import XCTest

class HealthKitSleepSummaryTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
    }

    override func tearDown() {
        calendar = nil
        super.tearDown()
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
    }

    private func sample(_ stage: HealthKitSleepStage, from start: Date, to end: Date) -> HealthKitSleepSample {
        HealthKitSleepSample(start: start, end: end, stage: stage)
    }

    /// An Apple Watch night: staged sleep with a couple of awake segments.
    private var watchNight: [HealthKitSleepSample] {
        [
            sample(.core, from: date(10, 23, 0), to: date(11, 0, 30)),
            sample(.deep, from: date(11, 0, 30), to: date(11, 1, 30)),
            sample(.awake, from: date(11, 1, 30), to: date(11, 1, 40)),
            sample(.rem, from: date(11, 1, 40), to: date(11, 2, 40)),
            sample(.core, from: date(11, 2, 40), to: date(11, 6, 50)),
            sample(.awake, from: date(11, 6, 50), to: date(11, 7, 0)),
        ]
    }

    func testSleepDayStartsAtSixInTheEvening() {
        XCTAssertEqual(
            HealthKitSleepSummary.sleepDayStart(containing: date(11, 7, 0), calendar: calendar),
            date(10, 18, 0)
        )
        XCTAssertEqual(
            HealthKitSleepSummary.sleepDayStart(containing: date(11, 18, 0), calendar: calendar),
            date(11, 18, 0)
        )
        XCTAssertEqual(
            HealthKitSleepSummary.sleepDayStart(containing: date(11, 23, 59), calendar: calendar),
            date(11, 18, 0)
        )
    }

    func testNoSamplesMeansNoNight() {
        XCTAssertNil(HealthKitSleepSummary.latestNight(in: [], calendar: calendar))
    }

    func testStagesAddUpAndTotalCoversEveryAsleepStage() throws {
        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: watchNight, calendar: calendar))

        XCTAssertEqual(night.start, date(10, 18, 0))
        XCTAssertEqual(night.minutes(in: [.core]), 340)
        XCTAssertEqual(night.minutes(in: [.deep]), 60)
        XCTAssertEqual(night.minutes(in: [.rem]), 60)
        XCTAssertEqual(night.minutes(in: [.awake]), 20)
        XCTAssertEqual(night.minutes(in: HealthKitSleepStage.asleepStages), 460)
    }

    func testOnlyTheLatestNightIsReported() throws {
        let earlierNight = [
            sample(.asleepUnspecified, from: date(9, 23, 0), to: date(10, 7, 0)),
        ]

        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: earlierNight + watchNight, calendar: calendar))

        XCTAssertEqual(night.start, date(10, 18, 0))
        XCTAssertEqual(night.minutes(in: HealthKitSleepStage.asleepStages), 460)
    }

    func testAnAfternoonNapJoinsTheNightBeforeIt() throws {
        let nap = [sample(.asleepUnspecified, from: date(11, 14, 0), to: date(11, 14, 30))]

        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: watchNight + nap, calendar: calendar))

        XCTAssertEqual(night.start, date(10, 18, 0))
        XCTAssertEqual(night.minutes(in: HealthKitSleepStage.asleepStages), 490)
    }

    func testSleepAfterSixInTheEveningStartsANewNight() throws {
        let eveningNap = [sample(.asleepUnspecified, from: date(11, 18, 30), to: date(11, 19, 0))]

        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: watchNight + eveningNap, calendar: calendar))

        XCTAssertEqual(night.start, date(11, 18, 0))
        XCTAssertEqual(night.minutes(in: HealthKitSleepStage.asleepStages), 30)
    }

    func testOverlappingSamplesFromSeveralSourcesCountOnce() throws {
        // A third-party app logging the same night as one unspecified block, plus an iPhone in-bed span.
        let otherSources = [
            sample(.asleepUnspecified, from: date(10, 23, 0), to: date(11, 7, 0)),
            sample(.inBed, from: date(10, 22, 45), to: date(11, 7, 10)),
        ]

        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: watchNight + otherSources, calendar: calendar))

        // 23:00 to 07:00 once, not the Watch's 460 minutes on top of the app's 480.
        XCTAssertEqual(night.minutes(in: HealthKitSleepStage.asleepStages), 480)
        XCTAssertEqual(night.minutes(in: [.deep]), 60)
    }

    func testDuplicateAndTouchingSamplesMergeIntoOne() throws {
        let samples = [
            sample(.deep, from: date(11, 1, 0), to: date(11, 2, 0)),
            sample(.deep, from: date(11, 1, 0), to: date(11, 2, 0)),
            sample(.deep, from: date(11, 2, 0), to: date(11, 2, 30)),
            sample(.deep, from: date(11, 1, 30), to: date(11, 1, 45)),
        ]

        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: samples, calendar: calendar))

        XCTAssertEqual(night.minutes(in: [.deep]), 90)
    }

    func testStageMissingFromAStagedNightIsZeroMinutes() throws {
        let noDeepSleep = watchNight.filter { $0.stage != .deep }

        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: noDeepSleep, calendar: calendar))

        XCTAssertEqual(night.minutes(in: [.deep]), 0)
    }

    func testStagesAreNotReportedForASourceThatDoesNotTrackThem() throws {
        let unstaged = [sample(.asleepUnspecified, from: date(10, 23, 0), to: date(11, 7, 0))]

        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: unstaged, calendar: calendar))

        XCTAssertEqual(night.minutes(in: HealthKitSleepStage.asleepStages), 480)
        XCTAssertNil(night.minutes(in: [.deep]))
        XCTAssertNil(night.minutes(in: [.awake]))
    }

    func testInBedOnlyNightHasTimeInBedButNoSleepDuration() throws {
        let inBed = [sample(.inBed, from: date(10, 23, 0), to: date(11, 7, 0))]

        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: inBed, calendar: calendar))

        XCTAssertEqual(night.minutes(in: [.inBed]), 480)
        XCTAssertNil(night.minutes(in: HealthKitSleepStage.asleepStages))
        XCTAssertNil(night.minutes(in: [.core]))
    }

    func testTimeInBedIsNotReportedForASourceThatOnlyRecordsSleep() throws {
        let night = try XCTUnwrap(HealthKitSleepSummary.latestNight(in: watchNight, calendar: calendar))

        XCTAssertNil(night.minutes(in: [.inBed]))
    }

    func testSleepAnalysisValuesMapToStages() {
        XCTAssertEqual(HealthKitSleepStage(sleepAnalysisValue: 0), .inBed)
        XCTAssertEqual(HealthKitSleepStage(sleepAnalysisValue: 1), .asleepUnspecified)
        XCTAssertEqual(HealthKitSleepStage(sleepAnalysisValue: 2), .awake)
        XCTAssertEqual(HealthKitSleepStage(sleepAnalysisValue: 3), .core)
        XCTAssertEqual(HealthKitSleepStage(sleepAnalysisValue: 4), .deep)
        XCTAssertEqual(HealthKitSleepStage(sleepAnalysisValue: 5), .rem)
        XCTAssertNil(HealthKitSleepStage(sleepAnalysisValue: 99))
    }
}
