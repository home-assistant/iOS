import WidgetKit

struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let family: WidgetFamily
    let complication: WatchWidgetComplicationSnapshot?
}
