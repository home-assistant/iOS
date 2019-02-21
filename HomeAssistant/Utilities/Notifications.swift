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
import CleanroomLogger

func ProvideNotificationCategoriesToSystem() {
    let realm = Current.realm()
    let categories = Set<UNNotificationCategory>(realm.objects(NotificationCategory.self).map({ $0.category }))

    Log.verbose?.message("Providing \(categories.count) categories to system: \(categories)")

    UNUserNotificationCenter.current().setNotificationCategories(categories)
}

func MigratePushSettingsToLocal() {
    let realm = Current.realm()

    HomeAssistantAPI.authenticatedAPI()?.getPushSettings().done { config in
        if let categories = config.Categories {
            for remoteCategory in categories {
                let localCategory = NotificationCategory()
                Log.verbose?.message("Attempting import of category \(remoteCategory.Identifier)")
                localCategory.Identifier = remoteCategory.Identifier
                localCategory.Name = remoteCategory.Name

                if let catActions = remoteCategory.Actions {
                    for remoteAction in catActions {
                        Log.verbose?.message("Attempting import of action \(remoteAction.Identifier)")
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
            Log.warning?.message("Unable to unwrap push categories or none exist! \(config)")
        }
    }.catch { error in
        Log.error?.message("Error when importing push settings: \(error)")
    }
}
