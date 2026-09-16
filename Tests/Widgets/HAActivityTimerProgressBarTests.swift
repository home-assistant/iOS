@testable import HomeAssistant

import Foundation
import Testing

struct HAActivityTimerProgressBarTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var end: Date { now.addingTimeInterval(600) }

    @available(iOS 17.2, *)
    @Test func countdownWithoutStartSpansNowToEnd() {
        let interval = HAActivityTimerProgressBar.interval(
            start: nil,
            timerStart: nil,
            end: end,
            direction: nil,
            now: now
        )
        #expect(interval?.range == now ... end)
        #expect(interval?.countsDown == true)
    }

    @available(iOS 17.2, *)
    @Test func timerStartReRangesBarAndKeepsDraining() {
        let cycleStart = now.addingTimeInterval(-1800)
        let interval = HAActivityTimerProgressBar.interval(
            start: nil,
            timerStart: cycleStart,
            end: end,
            direction: nil,
            now: now
        )
        #expect(interval?.range == cycleStart ... end)
        #expect(interval?.countsDown == true)
    }

    @available(iOS 17.2, *)
    @Test func increasingDirectionStillAppliesWithTimerStart() {
        let interval = HAActivityTimerProgressBar.interval(
            start: nil,
            timerStart: now.addingTimeInterval(-1800),
            end: end,
            direction: .increasing,
            now: now
        )
        #expect(interval?.countsDown == false)
    }

    @available(iOS 17.2, *)
    @Test func timerStartAtOrAfterEndFallsBackToNow() {
        for timerStart in [end, end.addingTimeInterval(1)] {
            let interval = HAActivityTimerProgressBar.interval(
                start: nil,
                timerStart: timerStart,
                end: end,
                direction: nil,
                now: now
            )
            #expect(interval?.range.lowerBound == now)
        }
    }

    @available(iOS 17.2, *)
    @Test func boundedCountUpStartWinsOverTimerStart() {
        let countUpStart = now.addingTimeInterval(-300)
        let interval = HAActivityTimerProgressBar.interval(
            start: countUpStart,
            timerStart: now.addingTimeInterval(-1800),
            end: end,
            direction: nil,
            now: now
        )
        #expect(interval?.range == countUpStart ... end)
        #expect(interval?.countsDown == false)
    }

    @available(iOS 17.2, *)
    @Test func scheduledBoundedCountUpKeepsFutureStart() {
        // The parser keeps a future explicit start as sent, so the bar must accept start > now.
        let futureStart = now.addingTimeInterval(300)
        let futureEnd = futureStart.addingTimeInterval(1800)
        let interval = HAActivityTimerProgressBar.interval(
            start: futureStart,
            timerStart: futureStart,
            end: futureEnd,
            direction: nil,
            now: now
        )
        #expect(interval?.range == futureStart ... futureEnd)
        #expect(interval?.countsDown == false)
    }

    @available(iOS 17.2, *)
    @Test func finishedCountdownHasNoBar() {
        let interval = HAActivityTimerProgressBar.interval(
            start: nil,
            timerStart: now.addingTimeInterval(-1800),
            end: now.addingTimeInterval(-1),
            direction: nil,
            now: now
        )
        #expect(interval == nil)
    }
}
