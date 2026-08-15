@testable import HomeAssistant

import Foundation
import Testing

struct WidgetEnergyPeriodTests {
    /// Fixed calendar and clock so "before 5 am" doesn't depend on the machine running the tests.
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private static func date(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: hour))!
    }

    @available(iOS 17, *)
    private static func fallback(atHour hour: Int) -> WidgetEnergyPeriod? {
        WidgetEnergyPeriod.today.emptyDataFallback(now: date(hour: hour), calendar: calendar)
    }

    @available(iOS 17, *)
    @Test func todayFallsBackToYesterdayEarlyInTheMorning() {
        #expect(Self.fallback(atHour: 0) == .yesterday)
        #expect(Self.fallback(atHour: 4) == .yesterday)
    }

    @available(iOS 17, *)
    @Test func todayKeepsItsOwnEmptyWindowFromFiveAm() {
        #expect(Self.fallback(atHour: 5) == nil)
        #expect(Self.fallback(atHour: 21) == nil)
    }

    @available(iOS 17, *)
    @Test func periodsOtherThanTodayNeverFallBack() {
        let earlyMorning = Self.date(hour: 2)
        for period in [WidgetEnergyPeriod.yesterday, .thisWeek, .thisMonth] {
            #expect(period.emptyDataFallback(now: earlyMorning, calendar: Self.calendar) == nil)
        }
    }

    @available(iOS 17, *)
    @Test func yesterdayRangeCoversTheWholePreviousDay() {
        let range = WidgetEnergyPeriod.yesterday.dateRange(now: Self.date(hour: 2), calendar: Self.calendar)

        #expect(range.start == Self.date(hour: 0).addingTimeInterval(-24 * 3600))
        #expect(range.end == Self.date(hour: 0))
    }
}
