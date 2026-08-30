import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

/// Upcoming events from any number of Home Assistant calendars, merged into one list.
@available(iOS 17, *)
struct WidgetCalendar: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.calendar.rawValue,
            provider: WidgetCalendarAppIntentTimelineProvider()
        ) { timelineEntry in
            WidgetCalendarView(
                referenceDate: timelineEntry.date,
                events: timelineEntry.events,
                calendarCount: timelineEntry.calendarCount,
                showsCalendarName: timelineEntry.showsCalendarName,
                calendar: Current.calendar(),
                serverId: timelineEntry.serverId
            )
            .widgetBackground(.primaryBackground)
        }
        .configurationDisplayName(L10n.Widgets.Calendar.title)
        .description(L10n.Widgets.Calendar.description)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@available(iOS 17, *)
#Preview(as: .systemSmall, widget: {
    WidgetCalendar()
}, timeline: {
    WidgetCalendarEntry(
        date: WidgetCalendarPreviewSample.referenceDate,
        events: Array(WidgetCalendarPreviewSample.events(
            referenceDate: WidgetCalendarPreviewSample.referenceDate,
            calendar: .current
        ).prefix(2)),
        calendarCount: 3,
        showsCalendarName: false,
        serverId: WidgetCalendarPreviewSample.previewServerId
    )
})

@available(iOS 17, *)
#Preview(as: .systemMedium, widget: {
    WidgetCalendar()
}, timeline: {
    WidgetCalendarEntry(
        date: WidgetCalendarPreviewSample.referenceDate,
        events: Array(WidgetCalendarPreviewSample.events(
            referenceDate: WidgetCalendarPreviewSample.referenceDate,
            calendar: .current
        ).prefix(3)),
        calendarCount: 3,
        showsCalendarName: true,
        serverId: WidgetCalendarPreviewSample.previewServerId
    )
})

@available(iOS 17, *)
#Preview(as: .systemLarge, widget: {
    WidgetCalendar()
}, timeline: {
    WidgetCalendarEntry(
        date: WidgetCalendarPreviewSample.referenceDate,
        events: Array(WidgetCalendarPreviewSample.events(
            referenceDate: WidgetCalendarPreviewSample.referenceDate,
            calendar: .current
        ).prefix(6)),
        calendarCount: 3,
        showsCalendarName: true,
        serverId: WidgetCalendarPreviewSample.previewServerId
    )
})
