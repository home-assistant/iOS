import WidgetKit
import Shared

struct WidgetActionsProvider: IntentTimelineProvider {
    typealias Intent = WidgetActionsIntent

    // start beta 3 compatibility code for github actions
    typealias Entry = WidgetActionsEntry

    func snapshot(for configuration: Intent, with context: Context, completion: @escaping (Entry) -> Void) {
        getSnapshot(for: configuration, in: context, completion: completion)
    }

    func timeline(for configuration: Intent, with context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        getTimeline(for: configuration, in: context, completion: completion)
    }
    // swiftlint:enable line_length
    // end beta 3 compatibility code

    func placeholder(in context: Context) -> Entry {
        .init(actions: [
            with(Action()) {
                $0.Text = "Example"
            }
        ])
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        completion(.init(actions: configuration.actions?.compactMap { $0.asAction() } ?? []))
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(.init(entries: [
            .init(actions: configuration.actions?.compactMap { $0.asAction() } ?? [])
        ], policy: .never))
    }
}
