import Foundation
@testable import HomeAssistant
import Shared
import Testing

struct HACompactTrailingLimitedWidthContentTests {
    private static let timerStart = Date(timeIntervalSince1970: 1_700_000_000)
    private static let timerEnd = timerStart.addingTimeInterval(1500)

    @available(iOS 17.2, *)
    @Test func boundedTimerWithProgressShowsTheProgress() {
        let state = HALiveActivityAttributes.ContentState(
            message: "Washing cycle",
            progress: 40,
            progressMax: 100,
            chronometer: true,
            countdownEnd: Self.timerEnd,
            chronometerStart: Self.timerStart
        )
        #expect(HACompactTrailingLimitedWidthContent(state: state) == .progressRing(fraction: 0.4))
    }

    @available(iOS 17.2, *)
    @Test func countdownWithProgressShowsTheProgress() {
        let state = HALiveActivityAttributes.ContentState(
            message: "Washing cycle",
            progress: 40,
            progressMax: 100,
            chronometer: true,
            countdownEnd: Date.distantFuture
        )
        #expect(HACompactTrailingLimitedWidthContent(state: state) == .progressRing(fraction: 0.4))
    }

    @available(iOS 17.2, *)
    @Test func timerWithProgressFollowsTheBarDirection() {
        let state = HALiveActivityAttributes.ContentState(
            message: "Washing cycle",
            progress: 25,
            progressMax: 100,
            chronometer: true,
            countdownEnd: Self.timerEnd,
            chronometerStart: Self.timerStart,
            progressBarDirection: "decreasing"
        )
        #expect(HACompactTrailingLimitedWidthContent(state: state) == .progressRing(fraction: 0.75))
    }

    @available(iOS 17.2, *)
    @Test func boundedTimerWithoutProgressShowsTheTimer() {
        let state = HALiveActivityAttributes.ContentState(
            message: "Pasta",
            chronometer: true,
            countdownEnd: Self.timerEnd,
            chronometerStart: Self.timerStart
        )
        #expect(
            HACompactTrailingLimitedWidthContent(state: state)
                == .timerRing(range: Self.timerStart ... Self.timerEnd, countsDown: false)
        )
    }

    @available(iOS 17.2, *)
    @Test func countdownWithoutProgressDrainsUntilItsEnd() {
        let state = HALiveActivityAttributes.ContentState(
            message: "Pasta",
            chronometer: true,
            countdownEnd: Date.distantFuture
        )
        guard case let .timerRing(range, countsDown)? = HACompactTrailingLimitedWidthContent(state: state) else {
            Issue.record("Expected a timer ring")
            return
        }
        #expect(range.upperBound == Date.distantFuture)
        #expect(countsDown)
    }

    @available(iOS 17.2, *)
    @Test func unboundedCountUpShowsTheElapsedTime() {
        let state = HALiveActivityAttributes.ContentState(
            message: "Workout",
            chronometer: true,
            countdownEnd: Self.timerStart
        )
        #expect(
            HACompactTrailingLimitedWidthContent(state: state) == .elapsedTime(end: Self.timerStart, start: nil)
        )
    }

    @available(iOS 17.2, *)
    @Test func timerComesBeforeCriticalText() {
        let state = HALiveActivityAttributes.ContentState(
            message: "Pasta",
            criticalText: "25 min",
            chronometer: true,
            countdownEnd: Self.timerEnd,
            chronometerStart: Self.timerStart
        )
        #expect(
            HACompactTrailingLimitedWidthContent(state: state)
                == .timerRing(range: Self.timerStart ... Self.timerEnd, countsDown: false)
        )
    }

    @available(iOS 17.2, *)
    @Test func criticalTextComesBeforeProgress() {
        let state = HALiveActivityAttributes.ContentState(
            message: "Charging paused",
            criticalText: "20%",
            progress: 20,
            progressMax: 100
        )
        #expect(HACompactTrailingLimitedWidthContent(state: state) == .criticalText("20%"))
    }

    @available(iOS 17.2, *)
    @Test func progressAloneShowsTheProgress() {
        let state = HALiveActivityAttributes.ContentState(
            message: "Washing cycle",
            progress: 40,
            progressMax: 100
        )
        #expect(HACompactTrailingLimitedWidthContent(state: state) == .progressRing(fraction: 0.4))
    }

    @available(iOS 17.2, *)
    @Test func messageOnlyShowsNothing() {
        let state = HALiveActivityAttributes.ContentState(message: "Front door unlocked")
        #expect(HACompactTrailingLimitedWidthContent(state: state) == nil)
    }
}
