#if !os(watchOS)
import Foundation
import SFSafeSymbols
import SwiftUI
import WidgetKit

/// The calendar widget's content, laid out after the iOS Calendar widget: a date badge, then the
/// events still to come, with the calendar's colour carried down the left of each row.
///
/// Everything is rendered against `referenceDate` rather than the clock, so a timeline entry always
/// draws the moment it was built for — and so the view can be snapshotted.
public struct WidgetCalendarContentView: View {
    /// Wraps a row in whatever opens it.
    public typealias RowContent = (WidgetCalendarEventModel, AnyView) -> AnyView

    private let referenceDate: Date
    private let events: [WidgetCalendarEventModel]
    private let calendarCount: Int
    private let showsCalendarName: Bool
    private let calendar: Calendar
    private let family: WidgetFamily
    private let strings: WidgetCalendarStrings
    private let logo: Image?
    private let rowContent: RowContent
    /// The reload control, when the widget offers one. An unconfigured widget doesn't.
    private let refreshControl: (() -> AnyView)?

    public init(
        referenceDate: Date,
        events: [WidgetCalendarEventModel],
        calendarCount: Int,
        showsCalendarName: Bool,
        calendar: Calendar,
        family: WidgetFamily,
        strings: WidgetCalendarStrings,
        logo: Image? = nil,
        rowContent: @escaping RowContent = { _, row in row },
        refreshControl: (() -> AnyView)? = nil
    ) {
        self.referenceDate = referenceDate
        self.events = events
        self.calendarCount = calendarCount
        self.showsCalendarName = showsCalendarName
        self.calendar = calendar
        self.family = family
        self.strings = strings
        self.logo = logo
        self.rowContent = rowContent
        self.refreshControl = refreshControl
    }

    /// One day's worth of events, as the larger families list them under a heading.
    private struct Day: Identifiable {
        let date: Date
        let events: [WidgetCalendarEventModel]

        var id: Date { date }
    }

    /// The events split into the days they belong to, in the order they are shown. Only the larger
    /// families use this — the small one never shows more than the next couple of events, where a
    /// day heading costs more room than it earns. An event already under way is grouped under the
    /// day being shown rather than the day it started on.
    private var days: [Day] {
        var order: [Date] = []
        var byDay: [Date: [WidgetCalendarEventModel]] = [:]
        for event in events {
            let day = calendar.startOfDay(for: max(event.start, referenceDate))
            if byDay[day] == nil {
                order.append(day)
            }
            byDay[day, default: []].append(event)
        }
        return order.map { Day(date: $0, events: byDay[$0] ?? []) }
    }

    /// What each piece of the layout costs in height at the default text size, each including the
    /// spacing that follows it. Deliberately rounded up: overestimating costs a row the widget
    /// could have shown, underestimating puts a row through the bottom edge.
    private enum Estimate {
        /// The date badge — a weekday over a 30pt day number — and the gap below it.
        static let badge: CGFloat = 55
        /// A day heading and the gap below it.
        static let heading: CGFloat = 21
        /// An event's title over its time, and the gap below it.
        static let row: CGFloat = 37
    }

    /// The day sections that fit in `height`, the room the widget has for the badge and the list.
    ///
    /// The provider caps the events it hands over, but a cap on events is not a cap on height: the
    /// same events cost a heading more for every extra day they are spread across, so five events
    /// on five days are half again as tall as five events on one. Dropping the tail of the list
    /// here is what keeps the date badge and the refresh footer where they belong — a widget on a
    /// smaller phone simply shows fewer days.
    private func visibleDays(in height: CGFloat) -> [Day] {
        var remaining = height - Estimate.badge
        var visible: [Day] = []
        for day in days {
            // A heading with no row under it names a day the widget then says nothing about, so a
            // section that cannot fit its first event is where the list stops.
            guard remaining >= Estimate.heading + Estimate.row else { break }
            remaining -= Estimate.heading
            let events = Array(day.events.prefix(Int(remaining / Estimate.row)))
            visible.append(Day(date: day.date, events: events))
            remaining -= CGFloat(events.count) * Estimate.row
        }
        return visible
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spaces.half) {
            // The list is the only part of the widget that grows with the schedule, so it is the
            // only part allowed to take the height left over — and it is held to it. A stack that
            // outgrows its widget is centred in it instead, which is what pushed the date badge off
            // the top and the refresh footer off the bottom. `visibleDays` trims the day-grouped
            // families to what fits; the clip is what makes overflowing impossible rather than
            // merely unlikely, at any family and any text size.
            GeometryReader { proxy in
                Group {
                    if calendarCount == .zero {
                        notConfigured
                    } else if family == .systemMedium {
                        mediumLayout
                    } else if family == .systemSmall {
                        smallLayout
                    } else {
                        dayGroupedLayout(in: proxy.size.height)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
            }
            // Reloading an unconfigured widget changes nothing, so the footer only appears once
            // there is something to refresh.
            if calendarCount != .zero, let refreshControl {
                HStack(spacing: .zero) {
                    Spacer(minLength: 0)
                    refreshControl()
                }
            }
        }
        // The unconfigured state already leads with the branded calendar glyph, so the logo there is
        // a second mark competing with it in a layout that is mostly empty space.
        .overlay(alignment: .topTrailing) {
            if family != .systemSmall, calendarCount != .zero, let logo {
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            }
        }
    }

    private var notConfigured: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Image(systemSymbol: .calendar)
                .font(.system(size: 32))
                .foregroundStyle(.haPrimary)
            Text(verbatim: strings.title)
                .font(DesignSystem.Font.callout.bold())
            Text(verbatim: strings.selectCalendars)
                .font(DesignSystem.Font.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.oneAndHalf) {
            WidgetCalendarDateBadgeView(date: referenceDate, calendar: calendar)
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                if events.isEmpty {
                    noEventsText
                } else {
                    ForEach(events) { event in
                        row(for: event, showsDay: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            WidgetCalendarDateBadgeView(date: referenceDate, calendar: calendar)
            if events.isEmpty {
                noEventsText
            } else {
                ForEach(events) { event in
                    row(for: event, showsDay: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func dayGroupedLayout(in height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            WidgetCalendarDateBadgeView(date: referenceDate, calendar: calendar)
            if events.isEmpty {
                noEventsText
            } else {
                ForEach(visibleDays(in: height)) { group in
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                        Text(verbatim: WidgetCalendarText.daySectionTitle(
                            for: group.date,
                            relativeTo: referenceDate,
                            calendar: calendar,
                            strings: strings
                        ))
                        .font(DesignSystem.Font.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        ForEach(group.events) { event in
                            row(for: event, showsDay: false)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var noEventsText: some View {
        Text(verbatim: strings.noEvents)
            .font(DesignSystem.Font.caption)
            .foregroundStyle(.secondary)
    }

    private func row(for event: WidgetCalendarEventModel, showsDay: Bool) -> AnyView {
        rowContent(event, AnyView(WidgetCalendarEventRowView(
            event: event,
            referenceDate: referenceDate,
            showsDay: showsDay,
            showsCalendarName: showsCalendarName,
            calendar: calendar,
            strings: strings
        )))
    }
}

#Preview("Events") {
    WidgetCalendarContentView(
        referenceDate: WidgetCalendarSampleData.referenceDate,
        events: Array(WidgetCalendarSampleData.events.prefix(3)),
        calendarCount: 3,
        showsCalendarName: true,
        calendar: .current,
        family: .systemMedium,
        strings: .preview
    )
    .padding(DesignSystem.Spaces.two)
    .frame(width: 338, height: 158)
}

#Preview("Not configured") {
    WidgetCalendarContentView(
        referenceDate: WidgetCalendarSampleData.referenceDate,
        events: [],
        calendarCount: 0,
        showsCalendarName: false,
        calendar: .current,
        family: .systemMedium,
        strings: .preview
    )
    .padding(DesignSystem.Spaces.two)
    .frame(width: 338, height: 158)
}
#endif
