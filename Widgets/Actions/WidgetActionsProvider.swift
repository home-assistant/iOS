import WidgetKit
import Shared

struct WidgetActionsEntry: TimelineEntry {
    var date: Date = Date()
    var actions: [Action] = []
}

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

    func placeholder(in context: Context) -> WidgetActionsEntry {
        .init()
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview {
            let count: Int = {
                switch context.family {
                case .systemSmall: return 1
                case .systemMedium: return 4
                case .systemLarge: return 8
                @unknown default: return 8
                }
            }()

            let actions = stride(from: 0, to: count, by: 1).map { _ in
                with(Action()) {
                    $0.Text = "Redacted Text"
                }
            }
            completion(.init(actions: actions))
        } else {
            completion(.init(actions: configuration.actions?.compactMap { $0.asAction() } ?? []))
        }
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(.init(entries: [
            .init(actions: configuration.actions?.compactMap { $0.asAction() } ?? [])
        ], policy: .never))
    }
}
