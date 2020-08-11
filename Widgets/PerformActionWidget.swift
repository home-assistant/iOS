import WidgetKit
import SwiftUI
import Shared
import Intents

struct PerformActionWidgetProvider: IntentTimelineProvider {
    typealias Intent = PerformActionIntent

    // start beta 3 compatibility code for github actions
    // swiftlint:disable line_length
    typealias Entry = PerformActionEntry

    func snapshot(for configuration: PerformActionIntent, with context: Context, completion: @escaping (Self.Entry) -> Void) {
        getSnapshot(for: configuration, in: context, completion: completion)
    }

    func timeline(for configuration: PerformActionIntent, with context: Context, completion: @escaping (Timeline<Self.Entry>) -> Void) {
        getTimeline(for: configuration, in: context, completion: completion)
    }
    // swiftlint:enable line_length
    // end beta 3 compatibility code

    func placeholder(in context: Self.Context) -> Self.Entry {
        PerformActionEntry(configuration: PerformActionIntent())
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        completion(.init(configuration: configuration))
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(.init(entries: [
            .init(configuration: configuration)
        ], policy: .never))
    }
}

struct PerformActionEntry: TimelineEntry {
    var date: Date = Date()
    var configuration: PerformActionIntent
}

struct PerformActionView: View {
    var entry: PerformActionEntry

    var body: some View {
        Text(entry.configuration.action?.displayString ?? "no action")
    }
}

struct PerformActionWidget: Widget {
    static let kind = "PerformAction"

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: Self.kind,
            intent: PerformActionIntent.self,
            provider: PerformActionWidgetProvider(),
            content: { PerformActionView(entry: $0) }
        )
        .configurationDisplayName("Perform Action")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
