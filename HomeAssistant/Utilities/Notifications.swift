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

    UNUserNotificationCenter.current().setNotificationCategories(categories)
}
