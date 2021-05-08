import Foundation
import PromiseKit
import RealmSwift
import Shared
import UserNotifications

extension NotificationCategory {
    static func setupObserver() {
        let categories = Current.realm().objects(NotificationCategory.self)

        Current.modelManager.observe(for: AnyRealmCollection(categories)) { collection in
            let fastlane = Promise<Set<UNNotificationCategory>> { seal in
                guard Current.appConfiguration == .FastlaneSnapshot else {
                    return seal.fulfill(Set())
                }

                seal.fulfill(Set(["CAMERA", "MAP"].map { identifier in
                    UNNotificationCategory(
                        identifier: identifier,
                        actions: [],
                        intentIdentifiers: [],
                        options: []
                    )
                }))
            }

            let builtin = Promise<Set<UNNotificationCategory>> { seal in
                var categories = Set<UNNotificationCategory>()

                let dynamicActions: [UNNotificationAction]

                if Current.isCatalyst {
                    dynamicActions = []
                } else {
                    dynamicActions = [
                        UNNotificationAction(
                            identifier: "LOADING",
                            title: L10n.NotificationService.loadingDynamicActions,
                            options: []
                        ),
                    ]
                }

                categories.insert(UNNotificationCategory(
                    identifier: "DYNAMIC",
                    actions: dynamicActions,
                    intentIdentifiers: [],
                    options: []
                ))

                seal.fulfill(categories)
            }

            let persisted = Promise<Set<UNNotificationCategory>> { seal in
                seal.fulfill(Set(collection.flatMap(\.categories)))
            }

            return when(fulfilled: [
                fastlane,
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
