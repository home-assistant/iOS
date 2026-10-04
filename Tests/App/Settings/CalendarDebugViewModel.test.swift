import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// The calendar debug screen's month grid, worked out without fetching any events. Assertions stay
/// relative to `Calendar.current` so they hold whatever first weekday or time zone the host uses.
@MainActor
@Suite(.serialized)
struct CalendarDebugViewModelTests {
    /// 15 March 2024, noon UTC: mid-month in every time zone.
    private static let now = Date(timeIntervalSince1970: 1_710_504_000)

    private static let haCalendar = HACalendar(
        id: "server-calendar.family",
        serverId: "server",
        entityId: "calendar.family",
        name: "Family",
        backgroundColor: "#4269d0",
        supportedFeatures: 5,
        sortOrder: 0
    )

    @Test func startsOnTodayWithASixWeekGrid() {
        withPinnedDate { viewModel in
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Self.now)

            #expect(viewModel.selectedDate == today)
            #expect(viewModel.visibleMonth == today)
            #expect(viewModel.visibleWeeks.count == 6)
            #expect(viewModel.visibleWeeks.allSatisfy { $0.count == 7 })

            let firstDay = viewModel.visibleWeeks[0][0]
            #expect(calendar.component(.weekday, from: firstDay) == calendar.firstWeekday)
            #expect(viewModel.visibleWeeks[0].contains { calendar.component(.day, from: $0) == 1 })

            #expect(viewModel.isToday(today))
            #expect(viewModel.isSelected(today))
            #expect(viewModel.isInVisibleMonth(today))
            #expect(viewModel.dayNumber(today) == String(calendar.component(.day, from: today)))
            #expect(viewModel.hasEvents(on: today) == false)
            #expect(viewModel.selectedDayEvents.isEmpty)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.monthTitle.isEmpty == false)
        }
    }

    @Test func weekdaySymbolsStartOnTheFirstWeekday() {
        withPinnedDate { viewModel in
            let calendar = Calendar.current
            let symbols = viewModel.weekdaySymbols

            #expect(symbols.count == 7)
            #expect(symbols.first == calendar.veryShortStandaloneWeekdaySymbols[calendar.firstWeekday - 1])
            #expect(Set(symbols) == Set(calendar.veryShortStandaloneWeekdaySymbols))
        }
    }

    @Test func movingMonthsPullsTheSelectionToTheFirstOfTheNewMonth() throws {
        try withPinnedDate { viewModel in
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Self.now)

            viewModel.showNextMonth()

            let nextMonth = try #require(calendar.date(byAdding: .month, value: 1, to: today))
            #expect(calendar.isDate(viewModel.visibleMonth, equalTo: nextMonth, toGranularity: .month))
            #expect(calendar.component(.day, from: viewModel.selectedDate) == 1)
            #expect(calendar.isDate(viewModel.selectedDate, equalTo: nextMonth, toGranularity: .month))
            #expect(viewModel.isInVisibleMonth(today) == false)
            #expect(viewModel.isSelected(today) == false)

            viewModel.showPreviousMonth()
            viewModel.showPreviousMonth()

            let previousMonth = try #require(calendar.date(byAdding: .month, value: -1, to: today))
            #expect(calendar.isDate(viewModel.visibleMonth, equalTo: previousMonth, toGranularity: .month))
            #expect(calendar.isDate(viewModel.selectedDate, equalTo: previousMonth, toGranularity: .month))
            #expect(viewModel.visibleWeeks.count == 6)
        }
    }

    @Test func selectingADayInTheVisibleMonthKeepsItWhenTheMonthIsShownAgain() {
        withPinnedDate { viewModel in
            let calendar = Calendar.current
            let day = viewModel.visibleWeeks[2][3]

            viewModel.selectedDate = day

            #expect(viewModel.isSelected(day))
            #expect(calendar.isDate(viewModel.visibleMonth, equalTo: Self.now, toGranularity: .month))
            #expect(viewModel.selectedDayEvents.isEmpty)
        }
    }

    @Test func calendarFeaturesComeFromTheBitmask() {
        #expect(Self.haCalendar.supports(.createEvent))
        #expect(Self.haCalendar.supports(.updateEvent))
        #expect(Self.haCalendar.supports(.deleteEvent) == false)
    }

    private func withPinnedDate(_ body: (CalendarDebugViewModel) throws -> Void) rethrows {
        let previousDate = Current.date
        defer { Current.date = previousDate }
        Current.date = { Self.now }

        let server = FakeServerManager().addFake()
        try body(CalendarDebugViewModel(server: server, calendar: Self.haCalendar))
    }
}
