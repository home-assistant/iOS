#if !os(watchOS)
import Foundation
import SwiftUI

/// One event in the calendar widget: the calendar's colour as a rule down the left, the summary,
/// and when it happens — the row the iOS Calendar widget uses at every size.
public struct WidgetCalendarEventRowView: View {
    private let event: WidgetCalendarEventModel
    /// The day the widget is showing, which is what decides whether the row has to name its own.
    private let referenceDate: Date
    /// Whether the row names the day it falls on when that isn't `referenceDate`. The large family
    /// groups events under a day heading instead, so it leaves this off.
    private let showsDay: Bool
    private let showsCalendarName: Bool
    private let calendar: Calendar
    private let strings: WidgetCalendarStrings

    public init(
        event: WidgetCalendarEventModel,
        referenceDate: Date,
        showsDay: Bool,
        showsCalendarName: Bool,
        calendar: Calendar,
        strings: WidgetCalendarStrings
    ) {
        self.event = event
        self.referenceDate = referenceDate
        self.showsDay = showsDay
        self.showsCalendarName = showsCalendarName
        self.calendar = calendar
        self.strings = strings
    }

    public var body: some View {
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
                Text(verbatim: WidgetCalendarText.subtitle(
                    for: event,
                    relativeTo: referenceDate,
                    showsDay: showsDay,
                    showsCalendarName: showsCalendarName,
                    calendar: calendar,
                    strings: strings
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

#Preview {
    VStack(spacing: DesignSystem.Spaces.one) {
        ForEach(WidgetCalendarSampleData.events) { event in
            WidgetCalendarEventRowView(
                event: event,
                referenceDate: WidgetCalendarSampleData.referenceDate,
                showsDay: true,
                showsCalendarName: true,
                calendar: .current,
                strings: .preview
            )
        }
    }
    .padding()
}
#endif
