//
//  HomeAssistantAPI+Notifications.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 9/16/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Crashlytics
import DeviceKit
import Foundation
import PromiseKit
import Shared
import UserNotifications

extension HomeAssistantAPI {
    func setupPushActions() -> Promise<Set<UIUserNotificationCategory>> {
        return Promise { seal in
            self.getPushSettings().done { pushSettings in
                var allCategories = Set<UIMutableUserNotificationCategory>()
                if let categories = pushSettings.Categories {
                    for category in categories {
                        let finalCategory = UIMutableUserNotificationCategory()
                        finalCategory.identifier = category.Identifier
                        var categoryActions = [UIMutableUserNotificationAction]()
                        if let actions = category.Actions {
                            for action in actions {
                                let newAction = UIMutableUserNotificationAction()
                                newAction.title = action.Title
                                newAction.identifier = action.Identifier
                                newAction.isAuthenticationRequired = action.AuthenticationRequired
                                newAction.isDestructive = action.Destructive
                                var behavior: UIUserNotificationActionBehavior = .default
                                if action.Behavior.lowercased() == "textinput" {
                                    behavior = .textInput
                                }
                                newAction.behavior = behavior
                                let foreground = UIUserNotificationActivationMode.foreground
                                let background = UIUserNotificationActivationMode.background
                                let mode = (action.ActivationMode == "foreground") ? foreground : background
                                newAction.activationMode = mode
                                if let textInputButtonTitle = action.TextInputButtonTitle {
                                    let titleKey = UIUserNotificationTextInputActionButtonTitleKey
                                    newAction.parameters[titleKey] = textInputButtonTitle
                                }
                                categoryActions.append(newAction)
                            }
                            finalCategory.setActions(categoryActions,
                                                     for: UIUserNotificationActionContext.default)
                            allCategories.insert(finalCategory)
                        } else {
                            print("Category has no actions defined, continuing loop")
                            continue
                        }
                    }
                }
                seal.fulfill(allCategories)
                }.catch { error in
                    CLSLogv("Error on setupPushActions() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    seal.reject(error)
            }
        }
    }

    func sendLocalNotification(withZone: RLMZone?, updateType: LocationUpdateTrigger,
                                       payloadDict: [String: Any]) {
        let zoneName = withZone?.Name ?? "Unknown zone"
        let notificationOptions = updateType.notificationOptionsFor(zoneName: zoneName)
        Current.clientEventStore.addEvent(ClientEvent(text: notificationOptions.body, type: .locationUpdate,
                                                      payload: payloadDict))
        if notificationOptions.shouldNotify {
            if #available(iOS 10, *) {
                let content = UNMutableNotificationContent()
                content.title = notificationOptions.title
                content.body = notificationOptions.body
                content.sound = UNNotificationSound.default()

                let notificationRequest =
                    UNNotificationRequest.init(identifier: notificationOptions.identifier ?? "",
                                               content: content, trigger: nil)
                UNUserNotificationCenter.current().add(notificationRequest)
            } else {
                let notification = UILocalNotification()
                notification.alertTitle = notificationOptions.title
                notification.alertBody = notificationOptions.body
                notification.alertAction = "open"
                notification.fireDate = NSDate() as Date
                notification.soundName = UILocalNotificationDefaultSoundName
                UIApplication.shared.scheduleLocalNotification(notification)
            }
        }
    }

    @available(iOS 10, *)
    func setupUserNotificationPushActions() -> Promise<Set<UNNotificationCategory>> {
        return Promise { seal in
            self.getPushSettings().done { pushSettings in
                var allCategories = Set<UNNotificationCategory>()
                if let categories = pushSettings.Categories {
                    for category in categories {
                        var categoryActions = [UNNotificationAction]()
                        if let actions = category.Actions {
                            for action in actions {
                                var actionOptions = UNNotificationActionOptions([])
                                if action.AuthenticationRequired { actionOptions.insert(.authenticationRequired) }
                                if action.Destructive { actionOptions.insert(.destructive) }
                                if action.ActivationMode == "foreground" { actionOptions.insert(.foreground) }
                                var newAction = UNNotificationAction(identifier: action.Identifier,
                                                                     title: action.Title, options: actionOptions)
                                if action.Behavior.lowercased() == "textinput",
                                    let btnTitle = action.TextInputButtonTitle,
                                    let place = action.TextInputPlaceholder {
                                    newAction = UNTextInputNotificationAction(identifier: action.Identifier,
                                                                              title: action.Title,
                                                                              options: actionOptions,
                                                                              textInputButtonTitle: btnTitle,
                                                                              textInputPlaceholder: place)
                                }
                                categoryActions.append(newAction)
                            }
                        } else {
                            continue
                        }
                        let finalCategory = UNNotificationCategory.init(identifier: category.Identifier,
                                                                        actions: categoryActions,
                                                                        intentIdentifiers: [],
                                                                        options: [.customDismissAction])
                        allCategories.insert(finalCategory)
                    }
                }
                seal.fulfill(allCategories)
                }.catch { error in
                    CLSLogv("Error on setupUserNotificationPushActions() request: %@",
                            getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    seal.reject(error)
            }
        }
    }

    func setupPush() {
        DispatchQueue.main.async(execute: {
            UIApplication.shared.registerForRemoteNotifications()
        })
        if #available(iOS 10, *) {
            self.setupUserNotificationPushActions().done { categories in
                UNUserNotificationCenter.current().setNotificationCategories(categories)
                }.catch {error -> Void in
                    print("Error when attempting to setup push actions", error)
                    Crashlytics.sharedInstance().recordError(error)
            }
        } else {
            self.setupPushActions().done { categories in
                let types: UIUserNotificationType = ([.alert, .badge, .sound])
                let settings = UIUserNotificationSettings(types: types, categories: categories)
                UIApplication.shared.registerUserNotificationSettings(settings)
                }.catch {error -> Void in
                    print("Error when attempting to setup push actions", error)
                    Crashlytics.sharedInstance().recordError(error)
            }
        }
    }

    func handlePushAction(identifier: String, userInfo: [AnyHashable: Any], userInput: String?) -> Promise<Bool> {
        return Promise { seal in
            guard let api = HomeAssistantAPI.authenticatedAPI() else {
                throw APIError.notConfigured
            }

            let device = Device()
            var eventData: [String: Any] = ["actionName": identifier,
                                            "sourceDevicePermanentID": Current.deviceIDProvider(),
                                            "sourceDeviceName": device.name,
                                            "sourceDeviceID": Current.settingsStore.deviceID]
            if let dataDict = userInfo["homeassistant"] {
                eventData["action_data"] = dataDict
            }
            if let textInput = userInput {
                eventData["response_info"] = textInput
                eventData["textInput"] = textInput
            }

            let eventType = "ios.notification_action_fired"
            api.createEvent(eventType: eventType, eventData: eventData).done { _ -> Void in
                seal.fulfill(true)
                }.catch {error in
                    Crashlytics.sharedInstance().recordError(error)
                    seal.reject(error)
            }
        }
    }

}
