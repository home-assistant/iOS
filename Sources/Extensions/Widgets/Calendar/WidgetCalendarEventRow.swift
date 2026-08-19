import Foundation
import Shared
import SwiftUI

/// One event in the calendar widget: the calendar's colour as a rule down the left, the summary,
/// and when it happens — the row the iOS Calendar widget uses at every size.
///
/// Tapping a row opens the frontend's calendar panel on the server the event came from, which is
/// the closest thing the frontend has to a detail view for a single occurrence.
@available(iOS 17, *)
struct WidgetCalendarEventRow: View {
    let event: WidgetCalendarEvent
    /// The day the widget is showing, which is what decides whether the row has to name its own.
    let referenceDate: Date
    /// Whether the row names the day it falls on when that isn't `referenceDate`. The large family
    /// groups events under a day heading instead, so it leaves this off.
    let showsDay: Bool
    let showsCalendarName: Bool
    let calendar: Calendar

    /// Opens the calendar panel on the event's own calendar. Falls back to plainly opening the app
    /// when the event carries no server id, which no event built from a stored calendar does.
    private var destination: URL {
        AppConstants.calendarOpenURL(serverId: event.serverId, entityId: event.calendarEntityId)?
            .withWidgetAuthenticity() ?? AppConstants.deeplinkURL
    }

    var body: some View {
        Link(destination: destination) {
            HStack(alignment: .center, spacing: DesignSystem.Spaces.one) {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.micro)
                    .fill(Color(hex: event.calendarColor))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.summary)
                        .font(DesignSystem.Font.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(verbatim: WidgetCalendarFormatter.subtitle(
                        for: event,
                        relativeTo: referenceDate,
                        showsDay: showsDay,
                        showsCalendarName: showsCalendarName,
                        calendar: calendar
                    ))
                    .font(DesignSystem.Font.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Without this the link tints its whole label with the accent colour, which turns every
        // event title blue and leaves the calendar's own colour bar as the only contrast.
        .buttonStyle(.plain)
    }
}

@available(iOS 17, *)
#Preview {
    // The sample's fixed reference date, shared by the events and the rows: two `Date()` calls
    // could straddle midnight and label rows against a day the events were not built around.
    let referenceDate = WidgetCalendarPreviewSample.referenceDate
    return VStack(spacing: DesignSystem.Spaces.one) {
        ForEach(
            WidgetCalendarPreviewSample.events(referenceDate: referenceDate, calendar: .current).prefix(6)
        ) { event in
            WidgetCalendarEventRow(
                event: event,
                referenceDate: referenceDate,
                showsDay: true,
                showsCalendarName: true,
                calendar: .current
            )
        }
    }
    .padding()
}
