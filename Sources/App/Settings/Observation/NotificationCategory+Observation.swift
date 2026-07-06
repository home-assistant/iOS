import Foundation
import PromiseKit
import Shared
import UserNotifications

extension NotificationCategory {
    static func setupObserver() {
        Current.modelManager.observe(for: NotificationCategory.self) { categories in
            let fastlane = Promise<Set<UNNotificationCategory>> { seal in
                guard Current.appConfiguration == .fastlaneSnapshot else {
                    return seal.fulfill(Set())
                }

                seal.fulfill(Set(["CAMERA", "MAP"].map { identifier in
                    UNNotificationCategory(
                        identifier: identifier,
                        actions: [],
                        intentIdentifiers: []
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
                            title: L10n.NotificationService.loadingDynamicActions
                        ),
                    ]
                }

                categories.insert(UNNotificationCategory(
                    identifier: "DYNAMIC",
                    actions: dynamicActions,
                    intentIdentifiers: []
                ))

                seal.fulfill(categories)
            }

            let persisted = Promise<Set<UNNotificationCategory>> { seal in
                seal.fulfill(Set(categories.flatMap(\.categories)))
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
