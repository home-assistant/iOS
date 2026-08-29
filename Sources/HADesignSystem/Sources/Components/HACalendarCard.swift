#if !os(watchOS)
import SwiftUI

/// A month at a glance, with the selected day's events listed under it. The SwiftUI counterpart of
/// the frontend's `hui-calendar-card`.
///
/// The frontend embeds a full calendar library and writes event titles into the day cells. On a
/// phone that is unreadable, so this keeps the month as a grid of dots — one per event, coloured by
/// calendar — and puts the titles in a list below, which is how a native calendar reads.
public struct HACalendarCard: View {
    private static let dayCellHeight: CGFloat = 36
    private static let dotSize: CGFloat = 5
    /// Beyond three, the dots would crowd the cell and stop reading as a count.
    private static let maximumDots = 3

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    private let title: String?
    private let month: Date
    private let selectedDay: Date
    private let events: [HACalendarCardEvent]
    private let onSelectDay: ((Date) -> Void)?

    /// - Parameters:
    ///   - month: Any instant within the month to show.
    ///   - selectedDay: The day whose events are listed. Passed in rather than held as state so the
    ///     card can be driven from a screen that already tracks it — and so it can be snapshotted.
    public init(
        title: String? = nil,
        month: Date,
        selectedDay: Date,
        events: [HACalendarCardEvent],
        onSelectDay: ((Date) -> Void)? = nil
    ) {
        self.title = title
        self.month = month
        self.selectedDay = selectedDay
        self.events = events
        self.onSelectDay = onSelectDay
    }

    private var workingCalendar: Calendar {
        var working = calendar
        working.timeZone = timeZone
        working.locale = locale
        return working
    }

    public var body: some View {
        HACard(header: title) {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                monthHeader
                weekdayHeader
                grid
                if !selectedDayEvents.isEmpty {
                    Divider()
                    eventList
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
    }

    // MARK: - Month

    private var monthHeader: some View {
        Text(month.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).month(.wide).year()))
            .font(DesignSystem.Font.headline)
    }

    private var weekdayHeader: some View {
        HStack(spacing: .zero) {
            // Identified by position, not by the symbol: `veryShortWeekdaySymbols` repeats itself in
            // plenty of locales — English has two "S" and two "T" — so `id: \.self` would hand
            // `ForEach` duplicate identities and let SwiftUI reuse or drop header cells.
            ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// The locale decides where the week starts — Sunday in the US, Monday across most of Europe —
    /// so the symbols are rotated to match rather than always starting at Sunday.
    private var orderedWeekdaySymbols: [String] {
        let symbols = workingCalendar.veryShortWeekdaySymbols
        let firstWeekday = workingCalendar.firstWeekday - 1
        guard firstWeekday > 0, firstWeekday < symbols.count else {
            return symbols
        }
        return Array(symbols[firstWeekday...] + symbols[..<firstWeekday])
    }

    /// The days of the month, preceded by however many blanks it takes to put the first one under
    /// the right weekday.
    private var gridDays: [Date?] {
        let working = workingCalendar
        guard let interval = working.dateInterval(of: .month, for: month),
              let dayCount = working.range(of: .day, in: .month, for: month)?.count else {
            return []
        }
        let firstWeekday = working.component(.weekday, from: interval.start)
        let leading = (firstWeekday - working.firstWeekday + 7) % 7
        let days = (0 ..< dayCount).compactMap {
            working.date(byAdding: .day, value: $0, to: interval.start)
        }
        return Array(repeating: nil, count: leading) + days
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: .zero), count: 7)
        return LazyVGrid(columns: columns, spacing: DesignSystem.Spaces.half) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: Self.dayCellHeight)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = workingCalendar.isDate(day, inSameDayAs: selectedDay)
        let dots = events(on: day).prefix(Self.maximumDots)
        return VStack(spacing: DesignSystem.Spaces.micro) {
            Text(String(workingCalendar.component(.day, from: day)))
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .frame(width: 26, height: 26)
                .background(isSelected ? Color.haPrimary : .clear)
                .clipShape(Circle())
            HStack(spacing: 2) {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, event in
                    Circle()
                        .fill(event.color)
                        .frame(width: Self.dotSize, height: Self.dotSize)
                }
            }
            .frame(height: Self.dotSize)
        }
        .frame(height: Self.dayCellHeight)
        .contentShape(Rectangle())
        .modify { view in
            if let onSelectDay {
                Button { onSelectDay(day) } label: { view }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Events

    /// Every event *overlapping* the day, not only those starting on it: an overnight or multi-day
    /// event belongs on each day it covers, and matching on `start` alone would drop it from every
    /// day after the first.
    private func events(on day: Date) -> [HACalendarCardEvent] {
        guard let dayInterval = workingCalendar.dateInterval(of: .day, for: day) else {
            return []
        }
        return events.filter { event in
            // A zero-length event has no interval to intersect, so it is placed by its start.
            guard event.end > event.start else {
                return workingCalendar.isDate(event.start, inSameDayAs: day)
            }
            return event.start < dayInterval.end && event.end > dayInterval.start
        }
    }

    private var selectedDayEvents: [HACalendarCardEvent] {
        events(on: selectedDay).sorted { $0.start < $1.start }
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            ForEach(selectedDayEvents) { event in
                HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                    // A bar rather than a dot: it grows with a wrapped title, which is what ties a
                    // two-line event to its calendar's colour.
                    Capsule()
                        .fill(event.color)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                        Text(event.title)
                            .font(DesignSystem.Font.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(timeLabel(for: event))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: .zero)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func timeLabel(for event: HACalendarCardEvent) -> String {
        guard !event.isAllDay else {
            return HADesignSystemEnvironment.current.strings.allDay
        }
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        return "\(event.start.formatted(style)) – \(event.end.formatted(style))"
    }
}

/// 2026-08-29 09:41:07 UTC, the instant the rest of the gallery pins.
private let sampleDay = Date(timeIntervalSince1970: 1_787_996_467)

#Preview {
    HACalendarCard(
        title: "Calendar",
        month: sampleDay,
        selectedDay: sampleDay,
        events: [
            .init(id: "1", title: "Bin day", start: sampleDay, end: sampleDay, isAllDay: true),
            .init(
                id: "2",
                title: "Dentist",
                start: sampleDay.addingTimeInterval(3600),
                end: sampleDay.addingTimeInterval(5400),
                color: .haSuccessColor
            ),
        ]
    )
    .padding()
    .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .gmt)
}

extension HACalendarCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-calendar-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
