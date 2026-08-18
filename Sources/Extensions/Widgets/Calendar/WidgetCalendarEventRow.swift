import Foundation
import Shared
import SwiftUI

/// One event in the calendar widget: the calendar's colour as a rule down the left, the summary,
/// and when it happens — the row the iOS Calendar widget uses at every size.
///
/// Tapping a row opens the frontend's calendar panel on the server the event came from, which is
/// the closest thing the frontend has to a detail view for a single occurrence.
struct WidgetCalendarEventRow: View {
    let event: WidgetCalendarEvent
    let showsCalendarName: Bool
    let calendar: Calendar

    /// Falls back to plainly opening the app when the event carries no server id, which no event
    /// built from a stored calendar does.
    private var destination: URL {
        AppConstants.calendarOpenURL(serverId: event.serverId)?.withWidgetAuthenticity() ?? AppConstants.deeplinkURL
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
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.one) {
        ForEach(WidgetCalendarPreviewSample.events(referenceDate: Date(), calendar: .current).prefix(3)) { event in
            WidgetCalendarEventRow(event: event, showsCalendarName: true, calendar: .current)
        }
    }
    .padding()
}
