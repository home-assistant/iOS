//
//  Notifications.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import Shared
import RealmSwift
import UserNotifications

func ProvideNotificationCategoriesToSystem() {
    let realm = Current.realm()
    let categories = Set<UNNotificationCategory>(realm.objects(NotificationCategory.self).map({ $0.category }))

    Current.Log.verbose("Providing \(categories.count) categories to system: \(categories)")

    UNUserNotificationCenter.current().setNotificationCategories(categories)
}

func MigratePushSettingsToLocal() {
    let realm = Current.realm()

    HomeAssistantAPI.authenticatedAPI()?.getPushSettings().done { config in
        if let categories = config.Categories {
            for remoteCategory in categories {
                let localCategory = NotificationCategory()
                Current.Log.verbose("Attempting import of category \(remoteCategory.Identifier)")
                localCategory.Identifier = remoteCategory.Identifier
                localCategory.Name = remoteCategory.Name

                if let catActions = remoteCategory.Actions {
                    for remoteAction in catActions {
                        Current.Log.verbose("Attempting import of action \(remoteAction.Identifier)")
                        let localAction = NotificationAction()
                        localAction.Title = remoteAction.Title
                        localAction.Identifier = remoteAction.Identifier
                        localAction.AuthenticationRequired = remoteAction.AuthenticationRequired
                        localAction.Foreground = (remoteAction.ActivationMode.lowercased() == "foreground")
                        localAction.Destructive = remoteAction.Destructive
                        localAction.TextInput = (remoteAction.Behavior.lowercased() == "textinput")
                        if let buttonTitle = remoteAction.TextInputButtonTitle {
                            localAction.TextInputButtonTitle = buttonTitle
                        }
                        if let placeholder = remoteAction.TextInputPlaceholder {
                            localAction.TextInputPlaceholder = placeholder
                        }

                        // swiftlint:disable:next force_try
                        try! realm.write {
                            realm.add(localAction, update: true)
                            localCategory.Actions.append(localAction)
                        }
                    }
                }

                // swiftlint:disable:next force_try
                try! realm.write {
                    realm.add(localCategory, update: true)
                }
            }
        } else {
            Current.Log.warning("Unable to unwrap push categories or none exist! \(config)")
        }
    }.catch { error in
        Current.Log.error("Error when importing push settings: \(error)")
    }
}
