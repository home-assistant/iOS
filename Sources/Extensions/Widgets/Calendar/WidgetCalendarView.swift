import Foundation
import Shared
import SwiftUI
import WidgetKit

/// The calendar widget: the design system draws the badge, the day sections and the rows; this adds
/// the links a tap follows and the reload control.
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

    /// The events a row can be traced back to, so a tap can open the calendar the row came from.
    /// The design system's row model carries only what it draws.
    private var eventsById: [String: WidgetCalendarEvent] {
        Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        WidgetCalendarContentView(
            referenceDate: referenceDate,
            events: events.map(\.designSystemModel),
            calendarCount: calendarCount,
            showsCalendarName: showsCalendarName,
            calendar: calendar,
            family: widgetFamily,
            strings: WidgetCalendarFormatter.strings,
            logo: Image(.logo),
            rowContent: rowContent,
            refreshControl: { AnyView(WidgetCalendarRefreshButton(date: referenceDate)) }
        )
        // A tap that misses an event opens the panel on everything rather than on one calendar. The
        // small family has no per-row links at all — WidgetKit only honours this one there — so it
        // is also what a tap anywhere on the small widget does.
        .widgetURL(serverId.flatMap { AppConstants.calendarOpenURL(serverId: $0)?.withWidgetAuthenticity() })
    }

    /// Opens the calendar panel on the event's own calendar. Falls back to plainly opening the app
    /// when the event carries no server id, which no event built from a stored calendar does.
    private func rowContent(model: WidgetCalendarEventModel, row: AnyView) -> AnyView {
        AnyView(
            Link(destination: destination(for: model)) {
                row
            }
            // Without this the link tints its whole label with the accent colour, which turns every
            // event title blue and leaves the calendar's own colour bar as the only contrast.
            .buttonStyle(.plain)
        )
    }

    private func destination(for model: WidgetCalendarEventModel) -> URL {
        guard let event = eventsById[model.id] else { return AppConstants.deeplinkURL }
        return AppConstants.calendarOpenURL(serverId: event.serverId, entityId: event.calendarEntityId)?
            .withWidgetAuthenticity() ?? AppConstants.deeplinkURL
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
