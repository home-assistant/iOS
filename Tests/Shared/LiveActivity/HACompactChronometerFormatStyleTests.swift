#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
@testable import Shared
import XCTest

@available(iOS 18.0, *)
final class HACompactChronometerFormatStyleTests: XCTestCase {
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

    func testCountdownDropsSecondsFromAnHourUp() {
        let style = countdown()
        XCTAssertEqual(style.format(remaining(8413)), "2:20")
        XCTAssertEqual(style.format(remaining(3600)), "1:00")
        XCTAssertEqual(style.format(remaining(93600)), "26:00")
    }

    func testCountdownKeepsSecondsBelowAnHour() {
        let style = countdown()
        XCTAssertEqual(style.format(remaining(3599)), "59:59")
        XCTAssertEqual(style.format(remaining(1213)), "20:13")
        XCTAssertEqual(style.format(remaining(553)), "9:13")
        XCTAssertEqual(style.format(remaining(13)), "0:13")
    }

    func testCountdownFloorsTowardsTheLowerMinute() {
        let style = countdown()
        XCTAssertEqual(style.format(remaining(8400)), "2:20")
        XCTAssertEqual(style.format(remaining(8399)), "2:19")
    }

    func testCountdownStopsAtZero() {
        let style = countdown()
        XCTAssertEqual(style.format(remaining(0.4)), "0:00")
        XCTAssertEqual(style.format(elapsed(600)), "0:00")
        XCTAssertNil(style.discreteInput(after: elapsed(600)))
    }

    func testCountdownUpdatesEveryMinuteAboveAnHour() throws {
        let style = countdown()
        let now = remaining(8413)
        XCTAssertEqual(style.format(now.addingTimeInterval(12.9)), "2:20")
        let next = try XCTUnwrap(style.discreteInput(after: now))
        XCTAssertEqual(style.format(next), "2:19")
    }

    func testCountdownUpdatesEverySecondBelowAnHour() throws {
        let style = countdown()
        let now = remaining(1213.5)
        XCTAssertEqual(style.format(now), "20:13")
        let next = try XCTUnwrap(style.discreteInput(after: now))
        XCTAssertEqual(style.format(next), "20:12")
        XCTAssertLessThan(next.timeIntervalSince(now), 1)
    }

    func testCountUpStartsAtZeroAndKeepsSecondsBelowAnHour() {
        let style = countUp()
        XCTAssertEqual(style.format(elapsed(-10)), "0:00")
        XCTAssertEqual(style.format(elapsed(0)), "0:00")
        XCTAssertEqual(style.format(elapsed(553)), "9:13")
        XCTAssertNil(style.discreteInput(before: elapsed(0)))
    }

    func testCountUpDropsSecondsFromAnHourUp() {
        let style = countUp()
        XCTAssertEqual(style.format(elapsed(3599)), "59:59")
        XCTAssertEqual(style.format(elapsed(3600)), "1:00")
        XCTAssertEqual(style.format(elapsed(8413)), "2:20")
    }

    func testBoundedCountUpFreezesAtItsEnd() {
        let end = elapsed(8413)
        let style = countUp(freezesAt: end)
        XCTAssertEqual(style.format(elapsed(8412)), "2:20")
        XCTAssertEqual(style.format(elapsed(9000)), "2:20")
        XCTAssertNil(style.discreteInput(after: end))
    }

    func testNeighbouringInputsBracketEveryDisplayedValue() throws {
        for style in [countdown(), countUp(), countUp(freezesAt: elapsed(8413))] {
            for offset in stride(from: -9000.0, through: 9000.0, by: 7.3) {
                let input = Self.anchor.addingTimeInterval(offset)
                let output = style.format(input)
                if let after = style.discreteInput(after: input) {
                    XCTAssertGreaterThan(after, input)
                    XCTAssertNotEqual(style.format(after), output)
                    let justBefore = try XCTUnwrap(style.input(before: after))
                    XCTAssertEqual(style.format(justBefore), output)
                }
                if let before = style.discreteInput(before: input) {
                    XCTAssertLessThan(before, input)
                    XCTAssertNotEqual(style.format(before), output)
                    let justAfter = try XCTUnwrap(style.input(after: before))
                    XCTAssertEqual(style.format(justAfter), output)
                }
            }
        }
    }
}
#endif
