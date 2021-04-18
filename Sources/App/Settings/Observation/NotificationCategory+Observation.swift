import Foundation
import PromiseKit
import RealmSwift
import Shared
import UserNotifications

extension NotificationCategory {
    static func setupObserver() {
        let categories = Current.realm().objects(NotificationCategory.self)

        Current.modelManager.observe(for: AnyRealmCollection(categories)) { collection in
            let builtin = Promise<Set<UNNotificationCategory>> { seal in
                guard Current.appConfiguration == .FastlaneSnapshot else {
                    return seal.fulfill(Set())
                }

                let basic = ["CAMERA", "MAP"].map { identifier in
                    UNNotificationCategory(
                        identifier: identifier,
                        actions: [],
                        intentIdentifiers: [],
                        options: []
                    )
                }

                let dynamic = [
                    UNNotificationCategory(
                        identifier: "DYNAMIC",
                        actions: [
                            UNNotificationAction(
                                identifier: "LOADING",
                                title: L10n.NotificationService.loadingDynamicActions,
                                options: []
                            )
                        ],
                        intentIdentifiers: [],
                        options: []
                    )
                ]

                seal.fulfill(Set(basic + dynamic))
            }

            let persisted = Promise<Set<UNNotificationCategory>> { seal in
                seal.fulfill(Set(collection.flatMap(\.categories)))
            }

            return when(fulfilled: [
                builtin,
                persisted,
            ]).done(on: .main) { unCategories in
                let provided = unCategories.reduce(into: Set(), { $0.formUnion($1) })
                Current.Log.verbose("registering \(provided.count) categories")
                UNUserNotificationCenter.current().setNotificationCategories(provided)
                UNUserNotificationCenter.current().getNotificationCategories { categories in
                    Current.Log.verbose("registered \(categories.count) categories")
                }
            }
        }
    }
}
