import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Shared state: events come over a process-wide HTTP stub for the server in `Current.servers`.
@Suite(.sharedState)
@MainActor
struct CalendarDebugViewModelTests {
    @Test func buildsAMonthGridAroundToday() throws {
        let world = try CalendarTestWorld()
        let viewModel = CalendarDebugViewModel(server: world.server, calendar: world.writable)
        #expect(viewModel.visibleWeeks.count == 6)
        #expect(viewModel.visibleWeeks.allSatisfy { $0.count == 7 })
        #expect(viewModel.weekdaySymbols.count == 7)
        #expect(!viewModel.monthTitle.isEmpty)
        let today = Calendar.current.startOfDay(for: Date())
        #expect(viewModel.isToday(today))
        #expect(viewModel.isSelected(today))
        #expect(viewModel.isInVisibleMonth(today))
        #expect(viewModel.dayNumber(today) == String(Calendar.current.component(.day, from: today)))
        #expect(!viewModel.hasEvents(on: today))
    }

    @Test func movingMonthsMovesTheSelectionWithIt() throws {
        let world = try CalendarTestWorld()
        let viewModel = CalendarDebugViewModel(server: world.server, calendar: world.writable)
        let title = viewModel.monthTitle
        viewModel.showNextMonth()
        #expect(viewModel.monthTitle != title)
        #expect(viewModel.isInVisibleMonth(viewModel.selectedDate))
        viewModel.showPreviousMonth()
        viewModel.showPreviousMonth()
        #expect(viewModel.isInVisibleMonth(viewModel.selectedDate))
        #expect(!viewModel.isToday(viewModel.selectedDate) || viewModel.monthTitle == title)
    }

    @Test func loadsTheMonthsEventsAndFiltersTheSelectedDay() async throws {
        let world = try CalendarTestWorld()
        try await world.run {
            let viewModel = CalendarDebugViewModel(server: world.server, calendar: world.writable)
            await viewModel.loadEvents()
            #expect(viewModel.errorMessage == nil)
            #expect(!viewModel.isLoading)
            let today = Calendar.current.startOfDay(for: Date())
            #expect(viewModel.hasEvents(on: today))
            // All-day first, then by start time.
            #expect(viewModel.selectedDayEvents.map(\.summary) == ["Bins", "Meeting", "Instant"])

            viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: 3, to: today)!
            #expect(viewModel.selectedDayEvents.isEmpty)
        }
    }

    @Test func aFailedFetchShowsTheError() async throws {
        let world = try CalendarTestWorld()
        try await world.run(eventsStatus: 500) {
            let viewModel = CalendarDebugViewModel(server: world.server, calendar: world.writable)
            await viewModel.loadEvents()
            #expect(viewModel.errorMessage != nil)
            #expect(viewModel.selectedDayEvents.isEmpty)
        }
    }
}
