//
//  UNNotificationContent+ClientEvent.swift
//  Shared
//
//  Created by Stephan Vanterpool on 8/26/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UserNotifications

public extension UNNotificationContent {
    var clientEventTitle: String {
        var eventText: String = ""
        if !self.title.isEmpty {
            eventText = "\(self.title)"
            if !self.subtitle.isEmpty {
                eventText += " - \(self.subtitle)"
            }
        } else if let message = (self.userInfo["aps"] as? [String: Any])?["alert"] as? String {
            eventText = message
        }

        return L10n.ClientEvents.EventType.Notification.title(eventText)
    }
}
