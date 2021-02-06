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
                if #available(iOS 13, *) {
                    UIMenuSystem.main.setNeedsRebuild()
                }
                seal.fulfill(())
            }

            let updateShortcuts = Promise<Void> { seal in
                UIApplication.shared.shortcutItems = collection.map(\.uiShortcut)
                seal.fulfill(())
            }

            let updateTodayWidget = Promise<Void> { seal in
                #if !targetEnvironment(macCatalyst)
                NCWidgetController().setHasContent(
                    !collection.isEmpty,
                    forWidgetWithBundleIdentifier: Constants.BundleID.appending(".TodayWidget")
                )
                #endif
                seal.fulfill(())
            }

            let updateWidgetKitWidgets = Promise<Void> { seal in
                if #available(iOS 14, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetActionsIntent.widgetKind)
                }

                seal.fulfill(())
            }

            let updateWatch = Promise<Void> { seal in
                let error = HomeAssistantAPI.SyncWatchContext()
                if let error = error {
                    seal.reject(error)
                } else {
                    seal.fulfill(())
                }
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
                updateTodayWidget,
                updateWidgetKitWidgets,
                updateWatch,
                updateSuggestions,
            ]).asVoid()
        }
    }
}
