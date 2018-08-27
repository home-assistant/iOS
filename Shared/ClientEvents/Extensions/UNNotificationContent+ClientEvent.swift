//
//  UNNotificationContent+ClientEvent.swift
//  Shared
//
//  Created by Stephan Vanterpool on 8/26/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UserNotifications

@available(iOS 10, *)
public extension UNNotificationContent {
    public var clientEventTitle: String {
        var eventText: String
        if !self.title.isEmpty {
            eventText = "Received Notification: \(self.title)"
            if !self.subtitle.isEmpty {
                eventText += " - \(self.subtitle)"
            }
        } else if let message = (self.userInfo["aps"] as? [String: Any])?["alert"] as? String {
            eventText = "Received Notification: \(message)"
        } else {
            eventText = "Received a Push Notification"
        }

        return eventText
    }
}
