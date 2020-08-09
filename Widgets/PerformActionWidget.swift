import WidgetKit
import SwiftUI

struct PerformActionWidgetProvider: TimelineProvider {
    func getSnapshot(in context: Context, completion: @escaping (PerformActionEntry) -> Void) {
        completion(.init(text: "test 123"))
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
        .configurationDisplayName("Game Status")
        .description("Shows an overview of your game status")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
