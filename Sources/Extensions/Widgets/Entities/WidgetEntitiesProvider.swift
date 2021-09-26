import Shared
import WidgetKit

struct WidgetEntitiesEntry: TimelineEntry {
    var date = Date()
    var entities: [String] = []
}

struct WidgetEntitiesProvider: IntentTimelineProvider {
    typealias Intent = WidgetEntitiesIntent
    typealias Entry = WidgetEntitiesEntry

    func placeholder(in context: Context) -> WidgetEntitiesEntry {
        return .init(entities: [])
    }

    private static func entry(for configuration: Intent, in context: Context) -> Entry {
        return .init(entities: [])
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Self.entry(for: configuration, in: context))
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(.init(entries: [Self.entry(for: configuration, in: context)], policy: .after(.init(timeIntervalSinceNow: Measurement<UnitDuration>(value: 15, unit: .minutes).converted(to: .seconds).value))))
    }
}
