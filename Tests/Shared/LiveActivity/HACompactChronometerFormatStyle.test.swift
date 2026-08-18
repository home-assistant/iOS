#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
@testable import Shared
import Testing

@available(iOS 18.0, *)
struct HACompactChronometerFormatStyleTests {
    private static let anchor = Date(timeIntervalSince1970: 1_700_000_000)
    private static let english = Locale(identifier: "en_US")

    private func countdown() -> HACompactChronometerFormatStyle {
        .init(anchor: Self.anchor, direction: .countingDown, locale: Self.english)
    }

    private func countUp(freezesAt: Date? = nil) -> HACompactChronometerFormatStyle {
        .init(anchor: Self.anchor, direction: .countingUp, freezesAt: freezesAt, locale: Self.english)
    }

    private func remaining(_ seconds: TimeInterval) -> Date {
        Self.anchor.addingTimeInterval(-seconds)
    }

    private func elapsed(_ seconds: TimeInterval) -> Date {
        Self.anchor.addingTimeInterval(seconds)
    }

    @Test func countdownDropsSecondsFromAnHourUp() {
        let style = countdown()
        #expect(style.format(remaining(8413)) == "2:20")
        #expect(style.format(remaining(3600)) == "1:00")
        #expect(style.format(remaining(93600)) == "26:00")
    }

    @Test func countdownKeepsSecondsBelowAnHour() {
        let style = countdown()
        #expect(style.format(remaining(3599)) == "59:59")
        #expect(style.format(remaining(1213)) == "20:13")
        #expect(style.format(remaining(553)) == "9:13")
        #expect(style.format(remaining(13)) == "0:13")
    }

    @Test func countdownFloorsTowardsTheLowerMinute() {
        let style = countdown()
        #expect(style.format(remaining(8400)) == "2:20")
        #expect(style.format(remaining(8399)) == "2:19")
    }

    @Test func countdownStopsAtZero() {
        let style = countdown()
        #expect(style.format(remaining(0.4)) == "0:00")
        #expect(style.format(elapsed(600)) == "0:00")
        #expect(style.discreteInput(after: elapsed(600)) == nil)
    }

    @Test func countdownUpdatesEveryMinuteAboveAnHour() {
        let style = countdown()
        let now = remaining(8413)
        #expect(style.format(now.addingTimeInterval(12.9)) == "2:20")
        let next = style.discreteInput(after: now)
        #expect(next != nil)
        #expect(next.map { style.format($0) } == "2:19")
    }

    @Test func countdownUpdatesEverySecondBelowAnHour() {
        let style = countdown()
        let now = remaining(1213.5)
        #expect(style.format(now) == "20:13")
        let next = style.discreteInput(after: now)
        #expect(next.map { style.format($0) } == "20:12")
        #expect(next.map { $0.timeIntervalSince(now) < 1 } == true)
    }

    @Test func countUpStartsAtZeroAndKeepsSecondsBelowAnHour() {
        let style = countUp()
        #expect(style.format(elapsed(-10)) == "0:00")
        #expect(style.format(elapsed(0)) == "0:00")
        #expect(style.format(elapsed(553)) == "9:13")
        #expect(style.discreteInput(before: elapsed(0)) == nil)
    }

    @Test func countUpDropsSecondsFromAnHourUp() {
        let style = countUp()
        #expect(style.format(elapsed(3599)) == "59:59")
        #expect(style.format(elapsed(3600)) == "1:00")
        #expect(style.format(elapsed(8413)) == "2:20")
    }

    @Test func boundedCountUpFreezesAtItsEnd() {
        let end = elapsed(8413)
        let style = countUp(freezesAt: end)
        #expect(style.format(elapsed(8412)) == "2:20")
        #expect(style.format(elapsed(9000)) == "2:20")
        #expect(style.discreteInput(after: end) == nil)
    }

    @Test func neighbouringInputsBracketEveryDisplayedValue() {
        for style in [countdown(), countUp(), countUp(freezesAt: elapsed(8413))] {
            for offset in stride(from: -9000.0, through: 9000.0, by: 7.3) {
                let input = Self.anchor.addingTimeInterval(offset)
                let output = style.format(input)
                if let after = style.discreteInput(after: input) {
                    #expect(after > input)
                    #expect(style.format(after) != output)
                    #expect(style.input(before: after).map { style.format($0) } == output)
                }
                if let before = style.discreteInput(before: input) {
                    #expect(before < input)
                    #expect(style.format(before) != output)
                    #expect(style.input(after: before).map { style.format($0) } == output)
                }
            }
        }
    }
}
#endif
