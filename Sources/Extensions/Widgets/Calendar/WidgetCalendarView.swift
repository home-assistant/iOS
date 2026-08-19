import Foundation
import Shared
import SwiftUI
import WidgetKit

/// The calendar widget's content, laid out after the iOS Calendar widget: a date badge, then the
/// events still to come, with the calendar's colour carried down the left of each row.
///
/// Everything is rendered against `referenceDate` rather than the clock, so a timeline entry always
/// draws the moment it was built for — and so the view can be snapshotted.
@available(iOS 17, *)
struct WidgetCalendarView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let referenceDate: Date
    let events: [WidgetCalendarEvent]
    let calendarCount: Int
    let showsCalendarName: Bool
    let calendar: Calendar
    /// Server for the whole-widget tap target. `nil` leaves the widget without one, which is what
    /// the unconfigured state wants — and what the previews and snapshots pass.
    let serverId: String?

    /// One day's worth of events, as the larger families list them under a heading.
    private struct Day: Identifiable {
        let date: Date
        let events: [WidgetCalendarEvent]

        var id: Date { date }
    }

    /// The events split into the days they belong to, in the order they are shown. Only the larger
    /// families use this — the small one never shows more than the next couple of events, where a
    /// day heading costs more room than it earns. An event already under way is grouped under the
    /// day being shown rather than the day it started on.
    private var days: [Day] {
        var order: [Date] = []
        var byDay: [Date: [WidgetCalendarEvent]] = [:]
        for event in events {
            let day = calendar.startOfDay(for: max(event.start, referenceDate))
            if byDay[day] == nil {
                order.append(day)
            }
            byDay[day, default: []].append(event)
        }
        return order.map { Day(date: $0, events: byDay[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.half) {
            Group {
                if calendarCount == .zero {
                    VStack(spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: .calendar)
                            .font(.system(size: 32))
                            .foregroundStyle(.haPrimary)
                        Text(verbatim: L10n.Widgets.Calendar.title)
                            .font(DesignSystem.Font.callout.bold())
                        Text(verbatim: L10n.Widgets.Calendar.selectCalendars)
                            .font(DesignSystem.Font.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if widgetFamily == .systemMedium {
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.oneAndHalf) {
                        WidgetCalendarDateBadge(date: referenceDate, calendar: calendar)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                            if events.isEmpty {
                                Text(verbatim: L10n.Widgets.Calendar.noEvents)
                                    .font(DesignSystem.Font.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(events) { event in
                                    WidgetCalendarEventRow(
                                        event: event,
                                        showsCalendarName: showsCalendarName,
                                        calendar: calendar
                                    )
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if widgetFamily == .systemSmall {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                        WidgetCalendarDateBadge(date: referenceDate, calendar: calendar)
                        if events.isEmpty {
                            Text(verbatim: L10n.Widgets.Calendar.noEvents)
                                .font(DesignSystem.Font.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(events) { event in
                                WidgetCalendarEventRow(
                                    event: event,
                                    showsCalendarName: showsCalendarName,
                                    calendar: calendar
                                )
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                        WidgetCalendarDateBadge(date: referenceDate, calendar: calendar)
                        if events.isEmpty {
                            Text(verbatim: L10n.Widgets.Calendar.noEvents)
                                .font(DesignSystem.Font.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(days) { group in
                                VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                                    Text(verbatim: WidgetCalendarFormatter.daySectionTitle(
                                        for: group.date,
                                        relativeTo: referenceDate,
                                        calendar: calendar
                                    ))
                                    .font(DesignSystem.Font.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    ForEach(group.events) { event in
                                        WidgetCalendarEventRow(
                                            event: event,
                                            showsCalendarName: showsCalendarName,
                                            calendar: calendar
                                        )
                                    }
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            // Reloading an unconfigured widget changes nothing, so the footer only appears once
            // there is something to refresh.
            if calendarCount != .zero {
                HStack(spacing: .zero) {
                    Spacer(minLength: 0)
                    WidgetCalendarRefreshButton(date: referenceDate)
                }
            }
        }
        // The unconfigured state already leads with the branded calendar glyph, so the logo there is
        // a second mark competing with it in a layout that is mostly empty space.
        .overlay(alignment: .topTrailing) {
            if widgetFamily != .systemSmall, calendarCount != .zero {
                Image(.logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            }
        }
        // A tap that misses an event opens the panel on everything rather than on one calendar. The
        // small family has no per-row links at all — WidgetKit only honours this one there — so it
        // is also what a tap anywhere on the small widget does.
        .widgetURL(serverId.flatMap { AppConstants.calendarOpenURL(serverId: $0)?.withWidgetAuthenticity() })
    }
}

// The family-specific previews live on `WidgetCalendar`, through WidgetKit's own preview macro:
// `\.widgetFamily` is read-only inside the widget extension, so a plain preview here cannot choose
// a family. These two cover the states that do not depend on one.
@available(iOS 17, *)
#Preview("Events") {
    WidgetCalendarView(
        referenceDate: WidgetCalendarPreviewSample.referenceDate,
        events: Array(WidgetCalendarPreviewSample.events(
            referenceDate: WidgetCalendarPreviewSample.referenceDate,
            calendar: .current
        ).prefix(3)),
        calendarCount: 3,
        showsCalendarName: true,
        calendar: .current,
        serverId: WidgetCalendarPreviewSample.previewServerId
    )
    .padding(DesignSystem.Spaces.two)
    .frame(width: 338, height: 158)
}

@available(iOS 17, *)
#Preview("Not configured") {
    WidgetCalendarView(
        referenceDate: WidgetCalendarPreviewSample.referenceDate,
        events: [],
        calendarCount: 0,
        showsCalendarName: false,
        calendar: .current,
        serverId: nil
    )
    .padding(DesignSystem.Spaces.two)
    .frame(width: 338, height: 158)
}
