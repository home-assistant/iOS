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

                let camera = ["camera", "CAMERA"].map {
                    UNNotificationCategory(
                        identifier: $0,
                        actions: [],
                        intentIdentifiers: [],
                        options: []
                    )
                }

                let map = ["map", "MAP"].map {
                    UNNotificationCategory(
                        identifier: $0,
                        actions: [],
                        intentIdentifiers: [],
                        options: []
                    )
                }

                let dynamic = ["DYNAMIC"].map {
                    UNNotificationCategory(
                        identifier: $0,
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
                }

                seal.fulfill(Set(camera + map + dynamic))
            }

            let persisted = Promise<Set<UNNotificationCategory>> { seal in
                seal.fulfill(Set(collection.flatMap(\.categories)))
            }

            return when(fulfilled: [
                fastlane,
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
