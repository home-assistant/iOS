import Foundation
import PromiseKit
import RealmSwift
import Shared
#if !targetEnvironment(macCatalyst)
import NotificationCenter
#endif
import Intents
import WidgetKit

extension Action {
    static func setupObserver() {
        let actions = Current.realm()
            .objects(Action.self)
            .sorted(byKeyPath: #keyPath(Action.Position))

        Current.modelManager.observe(for: AnyRealmCollection(actions)) { collection in
            let invalidateMenu = Promise<Void> { seal in
                UIMenuSystem.main.setNeedsRebuild()
                seal.fulfill(())
            }

            let updateShortcuts = Promise<Void> { seal in
                if !Current.isCatalyst {
                    UIApplication.shared.shortcutItems = collection.map(\.uiShortcut)
                }
                seal.fulfill(())
            }

            let updateWidgetKitWidgets = Promise<Void> { seal in
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.actions.rawValue)

                seal.fulfill(())
            }

            let updateSuggestions = Promise<Void> { seal in
                // if we ever want to start donating more than actions, this needs to be pulled out to a helper
                let intents = collection.map { PerformActionIntent(action: $0) }
                INVoiceShortcutCenter.shared.setShortcutSuggestions(Array(intents.map { .intent($0) }))
                seal.fulfill(())
            }

            return when(resolved: [
                invalidateMenu,
                updateShortcuts,
                updateWidgetKitWidgets,
                updateSuggestions,
            ]).asVoid()
        }
    }
}
