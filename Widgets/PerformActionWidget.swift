import WidgetKit
import SwiftUI

struct PerformActionWidgetProvider: TimelineProvider {
    // start beta 3 compatibility code
    typealias Entry = PerformActionEntry

    func snapshot(with context: Self.Context, completion: @escaping (Self.Entry) -> Void) {
        getSnapshot(in: context, completion: completion)
    }

    func timeline(with context: Self.Context, completion: @escaping (Timeline<Self.Entry>) -> Void) {
        getTimeline(in: context, completion: completion)
    }
    // end beta 3 compatibility code

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
