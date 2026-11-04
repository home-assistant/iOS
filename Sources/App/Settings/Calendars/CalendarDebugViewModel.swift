import Foundation
import Shared

@MainActor
final class CalendarDebugViewModel: ObservableObject {
    @Published private(set) var visibleMonth: Date
    @Published var selectedDate: Date {
        didSet { updateSelectedDayEvents() }
    }

    /// The month grid, already chunked into weeks. Stored rather than computed so laying out the
    /// grid doesn't redo the date arithmetic on every SwiftUI layout pass.
    @Published private(set) var visibleWeeks: [[Date]] = []
    /// Start-of-day for every visible day that has at least one event. A set lookup keeps the day
    /// cells cheap: filtering the whole event list per cell made scrolling stutter.
    @Published private(set) var daysWithEvents: Set<Date> = []
    @Published private(set) var selectedDayEvents: [HACalendarEvent] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let calendar: HACalendar

    private let server: Server
    private var events: [HACalendarEvent] = []
    /// Weeks are laid out with the user's first weekday, so the grid can start in the previous month
    /// and end in the next one; the fetch window covers whatever the grid shows.
    private let systemCalendar = Calendar.current

    init(server: Server, calendar: HACalendar) {
        self.server = server
        self.calendar = calendar
        let today = systemCalendar.startOfDay(for: Current.date())
        self.selectedDate = today
        self.visibleMonth = today
        rebuildVisibleWeeks()
    }

    /// Weekday initials in the user's first-weekday order.
    var weekdaySymbols: [String] {
        let symbols = systemCalendar.veryShortStandaloneWeekdaySymbols
        let offset = systemCalendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    func isInVisibleMonth(_ date: Date) -> Bool {
        systemCalendar.isDate(date, equalTo: visibleMonth, toGranularity: .month)
    }

    func isSelected(_ date: Date) -> Bool {
        systemCalendar.isDate(date, inSameDayAs: selectedDate)
    }

    func isToday(_ date: Date) -> Bool {
        systemCalendar.isDate(date, inSameDayAs: Current.date())
    }

    func hasEvents(on date: Date) -> Bool {
        daysWithEvents.contains(systemCalendar.startOfDay(for: date))
    }

    func dayNumber(_ date: Date) -> String {
        String(systemCalendar.component(.day, from: date))
    }

    func showPreviousMonth() {
        guard let previous = systemCalendar.date(byAdding: .month, value: -1, to: visibleMonth) else { return }
        show(month: previous)
    }

    func showNextMonth() {
        guard let next = systemCalendar.date(byAdding: .month, value: 1, to: visibleMonth) else { return }
        show(month: next)
    }

    func loadEvents() async {
        guard let start = visibleWeeks.first?.first, let last = visibleWeeks.last?.last,
              let end = systemCalendar.date(byAdding: .day, value: 1, to: last) else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            events = try await HomeAssistantAPI.calendarEvents(
                server: server,
                entityId: calendar.entityId,
                start: start,
                end: end
            )
            errorMessage = nil
        } catch {
            Current.Log.error("Failed to fetch events for \(calendar.entityId), error: \(error)")
            events = []
            errorMessage = error.localizedDescription
        }
        rebuildEventIndex(start: start, end: end)
        updateSelectedDayEvents()
    }

    /// Moves the grid to `month`, pulling the selection along when it would otherwise point at a day
    /// the grid no longer shows.
    private func show(month: Date) {
        visibleMonth = month
        rebuildVisibleWeeks()
        guard !systemCalendar.isDate(selectedDate, equalTo: month, toGranularity: .month),
              let monthInterval = systemCalendar.dateInterval(of: .month, for: month) else { return }
        selectedDate = systemCalendar.startOfDay(for: monthInterval.start)
    }

    /// The 42 days (6 weeks) the month grid renders, starting on the user's first weekday.
    private func rebuildVisibleWeeks() {
        guard let monthInterval = systemCalendar.dateInterval(of: .month, for: visibleMonth) else {
            visibleWeeks = []
            return
        }
        let weekday = systemCalendar.component(.weekday, from: monthInterval.start)
        let leading = (weekday - systemCalendar.firstWeekday + 7) % 7
        guard let gridStart = systemCalendar.date(byAdding: .day, value: -leading, to: monthInterval.start) else {
            visibleWeeks = []
            return
        }
        let days = (0 ..< 42).compactMap { offset in
            systemCalendar.date(byAdding: .day, value: offset, to: gridStart)
        }
        visibleWeeks = stride(from: 0, to: days.count, by: 7).map { weekStart in
            Array(days[weekStart ..< min(weekStart + 7, days.count)])
        }
    }

    /// Walks every event once and marks the days it covers, clamped to the fetched window so a
    /// multi-year recurring event can't spin here.
    private func rebuildEventIndex(start: Date, end: Date) {
        var days: Set<Date> = []
        for event in events {
            var day = systemCalendar.startOfDay(for: max(event.start, start))
            // All-day events carry an exclusive end; give zero-length events a moment so they still
            // land on their own day.
            let eventEnd = min(max(event.end, event.start.addingTimeInterval(1)), end)
            while day < eventEnd {
                days.insert(day)
                guard let next = systemCalendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        daysWithEvents = days
    }

    private func updateSelectedDayEvents() {
        let dayStart = systemCalendar.startOfDay(for: selectedDate)
        guard let dayEnd = systemCalendar.date(byAdding: .day, value: 1, to: dayStart) else {
            selectedDayEvents = []
            return
        }
        selectedDayEvents = events.filter { event in
            let end = max(event.end, event.start.addingTimeInterval(1))
            return event.start < dayEnd && end > dayStart
        }.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            return lhs.start < rhs.start
        }
    }
}
