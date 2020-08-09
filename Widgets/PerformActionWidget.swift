import WidgetKit
import SwiftUI

struct PerformActionWidgetProvider: TimelineProvider {
    func getSnapshot(in context: Context, completion: @escaping (PerformActionEntry) -> Void) {
        completion(.init(text: "snapshot"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PerformActionEntry>) -> Void) {
        completion(.init(entries: [PerformActionEntry(text: "timeline")], policy: .atEnd))
    }

    func placeholder(in context: Context) -> PerformActionEntry {
        .init(text: "placeholder")
    }
}

struct PerformActionEntry: TimelineEntry {
    var date: Date = Date()
    var text: String
}

struct PerformActionView: View {
    var entry: PerformActionEntry

    var body: some View {
        Text(entry.text)
    }
}

struct PerformActionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Test", provider: PerformActionWidgetProvider()) { (entry: PerformActionEntry) in
            PerformActionView(entry: entry)
        }
        .configurationDisplayName("Widget")
        .description("Widgets")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
