@testable import HomeAssistant
import XCTest

/// The RRULE Home Assistant stores, built from the recurrence rule Siri produces.
@available(iOS 27.0, *)
final class RecurrenceRuleRRULETests: XCTestCase {
    private func rule(
        _ frequency: Calendar.RecurrenceRule.Frequency,
        interval: Int = 1,
        end: Calendar.RecurrenceRule.End = .never
    ) -> Calendar.RecurrenceRule {
        Calendar.RecurrenceRule(calendar: .current, frequency: frequency, interval: interval, end: end)
    }

    func testEveryFrequencyMapsToItsICalendarName() {
        let expected: [(Calendar.RecurrenceRule.Frequency, String)] = [
            (.minutely, "MINUTELY"),
            (.hourly, "HOURLY"),
            (.daily, "DAILY"),
            (.weekly, "WEEKLY"),
            (.monthly, "MONTHLY"),
            (.yearly, "YEARLY"),
        ]

        for (frequency, name) in expected {
            XCTAssertEqual(rule(frequency).rrule, "FREQ=\(name)")
        }
    }

    /// Every day is the default, so it is left out rather than spelled as `INTERVAL=1`.
    func testAnIntervalOfOneIsLeftOut() {
        XCTAssertEqual(rule(.daily, interval: 1).rrule, "FREQ=DAILY")
        XCTAssertEqual(rule(.daily, interval: 3).rrule, "FREQ=DAILY;INTERVAL=3")
    }

    func testARuleThatNeverEndsCarriesNoEnd() {
        let rrule = rule(.weekly, interval: 2, end: .never).rrule

        XCTAssertEqual(rrule, "FREQ=WEEKLY;INTERVAL=2")
        XCTAssertEqual(rrule?.contains("COUNT"), false)
        XCTAssertEqual(rrule?.contains("UNTIL"), false)
    }

    func testARuleThatEndsAfterAFixedNumberOfTimesCarriesACount() {
        XCTAssertEqual(rule(.daily, end: .afterOccurrences(5)).rrule, "FREQ=DAILY;COUNT=5")
    }

    /// RFC 5545 wants UTC with a trailing `Z`, whatever the device's timezone is.
    func testARuleThatEndsOnADateCarriesThatDateInUTC() {
        let end = Date(timeIntervalSince1970: 1_700_000_000)
        let rrule = rule(.monthly, end: .afterDate(end)).rrule

        XCTAssertEqual(rrule, "FREQ=MONTHLY;UNTIL=20231114T221320Z")
        XCTAssertEqual(rrule?.hasSuffix("Z"), true)
    }

    func testIntervalAndEndAppearTogetherInRRULEOrder() {
        XCTAssertEqual(
            rule(.weekly, interval: 2, end: .afterOccurrences(10)).rrule,
            "FREQ=WEEKLY;INTERVAL=2;COUNT=10"
        )
    }
}
