import Foundation
import Shared
import RealmSwift
import PromiseKit
import NotificationCenter
import Intents

extension Action {
    static func setupObserver() {
        let actions = Current.realm()
            .objects(Action.self)
            .sorted(byKeyPath: #keyPath(Action.Position))

        Current.modelManager.observe(for: AnyRealmCollection(actions)) { collection in
            let updateShortcuts = Promise<Void> { seal in
                UIApplication.shared.shortcutItems = collection.map(\.uiShortcut)
                seal.fulfill(())
            }

            let updateWidget = Promise<Void> { seal in
                NCWidgetController().setHasContent(
                    !collection.isEmpty,
                    forWidgetWithBundleIdentifier: Constants.BundleID.appending(".TodayWidget")
                )
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
                if #available(iOS 12, *) {
                    // if we ever want to start donating more than actions, this needs to be pulled out to a helper
                    let intents = collection.map { PerformActionIntent(action: $0) }
                    INVoiceShortcutCenter.shared.setShortcutSuggestions(Array(intents.map { .intent($0) }))
                }

                seal.fulfill(())
            }

            return when(resolved: [
                updateShortcuts,
                updateWidget,
                updateWatch,
                updateSuggestions
            ]).asVoid()
        }
    }
}
