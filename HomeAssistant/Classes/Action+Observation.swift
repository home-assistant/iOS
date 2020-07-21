import Foundation
import Shared
import RealmSwift
import PromiseKit
import NotificationCenter

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

            return when(resolved: [
                updateShortcuts,
                updateWidget,
                updateWatch
            ]).asVoid()
        }
    }
}
