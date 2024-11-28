import AppIntents
import RealmSwift
import Shared
import WidgetKit

@available(iOS 17, *)
struct WidgetActionsAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetActionsEntry
    typealias Intent = WidgetActionsAppIntent

    func snapshot(for configuration: WidgetActionsAppIntent, in context: Context) async -> WidgetActionsEntry {
        await withCheckedContinuation({ continuation in
            Self.entry(for: configuration, in: context) { entries in
                continuation.resume(returning: entries)
            }
        })
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entries = await withCheckedContinuation({ continuation in
            Self.entry(for: configuration, in: context) { entries in
                continuation.resume(returning: entries)
            }
        })
        return .init(
            entries: [entries],
            policy: .after(
                Current.date()
                    .addingTimeInterval(WidgetActionsDataSource.expiration.converted(to: .seconds).value)
            )
        )
    }

    func placeholder(in context: Context) -> WidgetActionsEntry {
        let count = WidgetFamilySizes.size(for: context.family)
        let actions = stride(from: 0, to: count, by: 1).map { _ in
            with(Action()) {
                $0.Text = "Redacted Text"
                $0.IconName = MaterialDesignIcons.bedEmptyIcon.name
            }
        }

        return WidgetActionsEntry(actions: actions)
    }

    private static func entry(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        if !(configuration.actions?.isEmpty ?? true) {
            var actions: [Action?] = []
            var intentActionCheckCount = 0
            configuration.actions?.forEach({ intentAction in
                intentAction.asAction { action in
                    actions.append(action)
                    intentActionCheckCount += 1
                    if intentActionCheckCount == (configuration.actions?.count ?? 0) {
                        completion(.init(actions: actions.compactMap({ $0 })))
                    }
                }
            })
        } else {
            defaultActions(in: context) { actions in
                completion(.init(actions: actions))
            }
        }
    }

    private static func defaultActions(in context: Context, completion: @escaping ([Action]) -> Void) {
        WidgetActionsDataSource.actions { allActions in
            let maxCount = WidgetFamilySizes.size(for: context.family)
            switch allActions.count {
            case 0:
                completion([])
            case ...maxCount:
                completion(Array(allActions))
            default:
                completion(Array(allActions[0 ..< maxCount]))
            }
        }
    }
}

@available(iOS 17, *)
extension IntentActionAppEntity {
    func asAction(completion: @escaping (Action?) -> Void) {
        guard id.isEmpty == false else {
            completion(nil)
            return
        }
        func getAction() -> Action? {
            Current.realm(objectTypes: [Action.self, RLMScene.self]).object(
                ofType: Action.self,
                forPrimaryKey: id
            )
        }

        /*
         Workaround for iOS 18,
         'Realm accessed from incorrect thread.' if not called from main thread
         while in iOS 17 it reports the same error if called in the main thread
         */
        if #available(iOS 18, *) {
            DispatchQueue.main.async {
                completion(getAction())
            }
        } else {
            completion(getAction())
        }
    }
}

enum WidgetActionsDataSource {
    static var expiration: Measurement<UnitDuration> {
        .init(value: 24, unit: .hours)
    }

    static func getActions() -> Results<Action> {
        Current.realm(objectTypes: [Action.self, RLMScene.self]).objects(Action.self)
            .sorted(byKeyPath: #keyPath(Action.Position))
    }

    static func actions(completion: @escaping (Results<Action>) -> Void) {
        /*
         Workaround for iOS 18,
         'Realm accessed from incorrect thread.' if not called from main thread
         while in iOS 17 it reports the same error if called in the main thread
         */
        if #available(iOS 18, *) {
            DispatchQueue.main.async {
                completion(getActions())
            }
        } else {
            completion(getActions())
        }
    }
}
