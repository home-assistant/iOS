import AppIntents
import Foundation
import Shared
import WidgetKit

/// Builds the calendar widget's timeline by merging the selected calendars into one list of
/// upcoming events.
///
/// The events are read through `Current.calendarsModel()`, which fetches from the server, refreshes
/// the cache, and falls back to the cache when the server can't be reached — so the widget keeps
/// showing the last known schedule while the phone is off the network.
@available(iOS 17, *)
struct WidgetCalendarAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetCalendarEntry
    typealias Intent = WidgetCalendarAppIntent

    /// How far ahead events are fetched. Two weeks is enough to fill the largest family even for a
    /// sparse calendar, without asking a server for a whole year on every refresh.
    private static let lookahead: TimeInterval = 14 * 24 * 60 * 60
    /// Cap on entries per timeline. Each one costs memory in WidgetKit's archive; a day with more
    /// transitions than this reloads as soon as the entries run out.
    private static let maximumEntries = 12
    /// How long before the widget asks for fresh events. Entries already cover events starting and
    /// ending, so this only governs picking up changes made on the server.
    private static let refreshInterval: TimeInterval = 60 * 60

    func placeholder(in context: Context) -> Entry {
        let calendar = Current.calendar()
        let referenceDate = Current.date()
        return .init(
            date: referenceDate,
            events: WidgetCalendarEvent.upcoming(
                WidgetCalendarPreviewSample.events(referenceDate: referenceDate, calendar: calendar),
                at: referenceDate,
                limit: WidgetFamilySizes.calendarSize(for: context.family),
                calendar: calendar
            ),
            calendarCount: 3,
            showsCalendarName: context.family != .systemSmall,
            serverId: WidgetCalendarPreviewSample.previewServerId
        )
    }

    /// `context.isPreview` is WidgetKit's hook for the gallery, which it asks for before anything is
    /// configured. The sample below shows what the widget looks like in use without reaching for
    /// anyone's real schedule.
    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        guard !context.isPreview else { return placeholder(in: context) }
        return await entry(for: configuration, at: Current.date(), in: context)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        guard !context.isPreview else {
            return Timeline(entries: [placeholder(in: context)], policy: .never)
        }

        let now = Current.date()
        let calendar = Current.calendar()
        let limit = WidgetFamilySizes.calendarSize(for: context.family)
        let (events, calendars) = await fetch(for: configuration, at: now, calendar: calendar)

        let entries = transitions(of: events, from: now, calendar: calendar).map { date in
            WidgetCalendarEntry(
                date: date,
                events: WidgetCalendarEvent.upcoming(events, at: date, limit: limit, calendar: calendar),
                calendarCount: calendars.count,
                showsCalendarName: configuration.showsCalendarName,
                serverId: calendars.first?.serverId
            )
        }

        // Never later than the last entry: a day busy enough for `transitions` to be truncated runs
        // out of entries before the interval elapses, and WidgetKit would keep showing the last one
        // — listing events that have since ended — until the reload came due.
        let reloadAt = min(
            now.addingTimeInterval(Self.refreshInterval),
            entries.last?.date ?? now.addingTimeInterval(Self.refreshInterval)
        )
        return Timeline(entries: entries, policy: .after(reloadAt))
    }

    /// The moments the widget's content visibly changes: now, every point an event drops off the
    /// list, and the start of the next day so the date badge turns over even on an empty calendar.
    private func transitions(
        of events: [WidgetCalendarEvent],
        from now: Date,
        calendar: Calendar
    ) -> [Date] {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        let dates = events.map(\.end) + [nextDay].compactMap { $0 }
        let upcoming = Set(dates.filter { $0 > now }).sorted()
        return [now] + upcoming.prefix(Self.maximumEntries - 1)
    }

    /// Reads every selected calendar in parallel; one calendar failing leaves the others intact,
    /// because `HACalendarsModelProtocol.events` returns what it has rather than throwing.
    private func fetch(
        for configuration: Intent,
        at now: Date,
        calendar: Calendar
    ) async -> (events: [WidgetCalendarEvent], calendars: [HACalendar]) {
        let calendars = selectedCalendars(for: configuration)
        guard !calendars.isEmpty else { return ([], []) }

        let start = calendar.startOfDay(for: now)
        let end = start.addingTimeInterval(Self.lookahead)

        let events = await withTaskGroup(of: [WidgetCalendarEvent].self) { group in
            for haCalendar in calendars {
                group.addTask {
                    await Current.calendarsModel()
                        .events(for: haCalendar, start: start, end: end)
                        .map { WidgetCalendarEvent(event: $0, calendar: haCalendar) }
                }
            }
            var merged: [WidgetCalendarEvent] = []
            for await calendarEvents in group {
                merged += calendarEvents
            }
            return merged
        }

        return (events, calendars)
    }

    /// Selecting nothing means "everything": a freshly added widget shows the household's schedule
    /// before it has been configured, which is what the iOS Calendar widget does too.
    private func selectedCalendars(for configuration: Intent) -> [HACalendar] {
        let selected = (configuration.calendars ?? []).compactMap { HACalendar.get(id: $0.id) }
        return selected.isEmpty ? HACalendar.all() : selected
    }

    private func entry(for configuration: Intent, at now: Date, in context: Context) async -> Entry {
        let calendar = Current.calendar()
        let (events, calendars) = await fetch(for: configuration, at: now, calendar: calendar)
        return .init(
            date: now,
            events: WidgetCalendarEvent.upcoming(
                events,
                at: now,
                limit: WidgetFamilySizes.calendarSize(for: context.family),
                calendar: calendar
            ),
            calendarCount: calendars.count,
            showsCalendarName: configuration.showsCalendarName,
            serverId: calendars.first?.serverId
        )
    }
}
