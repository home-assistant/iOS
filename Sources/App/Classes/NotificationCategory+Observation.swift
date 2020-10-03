import Foundation
import Shared
import RealmSwift
import PromiseKit
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
                        options: UNNotificationCategoryOptions([.customDismissAction])
                    )
                }

                let map = ["map", "MAP"].map {
                    UNNotificationCategory(
                        identifier: $0,
                        actions: [],
                        intentIdentifiers: [],
                        options: UNNotificationCategoryOptions([.customDismissAction])
                    )
                }

                seal.fulfill(Set(camera + map))
            }

            let persisted = Promise<Set<UNNotificationCategory>> { seal in
                seal.fulfill(Set(collection.flatMap { $0.categories }))
            }

            return when(fulfilled: [
                fastlane,
                persisted
            ]).done(on: .main) { unCategories in
                let provided = unCategories.reduce(into: Set(), { $0.formUnion($1) })
                Current.Log.verbose("registering \(provided.map { $0.identifier })")
                UNUserNotificationCenter.current().setNotificationCategories(provided)
            }
        }
    }
}
