import Foundation
import UserNotifications
import FirebaseMessaging
import Shared
import PromiseKit
import XCGLogger
import CallbackURLKit

class NotificationManager: NSObject {
    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
    }

    func setupFirebase() {
        Current.Log.verbose("Calling UIApplication.shared.registerForRemoteNotifications()")
        UIApplication.shared.registerForRemoteNotifications()

        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = Current.settingsStore.privacy.messaging
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        Current.Log.error("failed to register for remote notifications: \(error)")
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Current.Log.verbose("Successfully registered for push notifications! APNS token: \(apnsToken)")
        Current.crashReporter.setUserProperty(value: apnsToken, name: "APNS Token")

        var tokenType: MessagingAPNSTokenType = .prod

        if Current.appConfiguration == .Debug {
            tokenType = .sandbox
        }

        Messaging.messaging().setAPNSToken(deviceToken, type: tokenType)
    }

    func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Current.Log.verbose("Received remote notification in completion handler!")

        Messaging.messaging().appDidReceiveMessage(userInfo)

        if let userInfoDict = userInfo as? [String: Any],
            let hadict = userInfoDict["homeassistant"] as? [String: String], let command = hadict["command"] {
                switch command {
                case "request_location_update":
                    if prefs.bool(forKey: "locationUpdateOnNotification") == false {
                        completionHandler(.noData)
                        return
                    }

                    Current.Log.verbose("Received remote request to provide a location update")

                    Current.backgroundTask(withName: "push-location-request") { remaining in
                        Current.api.then { api in
                            api.GetAndSendLocation(trigger: .PushNotification, maximumBackgroundTime: remaining)
                        }
                    }.done { success in
                        Current.Log.verbose("Did successfully send location when requested via APNS? \(success)")
                        completionHandler(.newData)
                    }.catch { error in
                        Current.Log.error("Error when attempting to submit location update: \(error)")
                        completionHandler(.failed)
                    }
                case "clear_badge":
                    Current.Log.verbose("Setting badge to 0 as requested")
                    UIApplication.shared.applicationIconBadgeNumber = 0
                default:
                    Current.Log.warning("Received unknown command via APNS! \(userInfo)")
                    completionHandler(.noData)
                }
        } else {
            completionHandler(.failed)
        }
    }

    // swiftlint:disable:next function_body_length
    fileprivate func handleShortcutNotification(
        _ shortcutName: String,
        _ shortcutDict: [String: String]
    ) {
        var inputParams: CallbackURLKit.Parameters = shortcutDict
        inputParams["name"] = shortcutName

        Current.Log.verbose("Sending params in shortcut \(inputParams)")

        let eventName: String = "ios.shortcut_run"
        let deviceDict: [String: String] = [
            "sourceDevicePermanentID": Constants.PermanentID, "sourceDeviceName": UIDevice.current.name,
            "sourceDeviceID": Current.settingsStore.deviceID
        ]
        var eventData: [String: Any] = ["name": shortcutName, "input": shortcutDict, "device": deviceDict]

        var successHandler: CallbackURLKit.SuccessCallback?

        if shortcutDict["ignore_result"] == nil {
            successHandler = { (params) in
                Current.Log.verbose("Received params from shortcut run \(String(describing: params))")
                eventData["status"] = "success"
                eventData["result"] = params?["result"]

                Current.Log.verbose("Success, sending data \(eventData)")

                Current.api.then { api in
                    api.CreateEvent(eventType: eventName, eventData: eventData)
                }.catch { error -> Void in
                    Current.Log.error("Received error from createEvent during shortcut run \(error)")
                }
            }
        }

        let failureHandler: CallbackURLKit.FailureCallback = { (error) in
            eventData["status"] = "failure"
            eventData["error"] = error.XCUErrorParameters

            Current.api.then { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }.catch { error -> Void in
                Current.Log.error("Received error from createEvent during shortcut run \(error)")
            }
        }

        let cancelHandler: CallbackURLKit.CancelCallback = {
            eventData["status"] = "cancelled"

            Current.api.then { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }.catch { error -> Void in
                Current.Log.error("Received error from createEvent during shortcut run \(error)")
            }
        }

        do {
            try Manager.shared.perform(action: "run-shortcut", urlScheme: "shortcuts",
                                       parameters: inputParams, onSuccess: successHandler,
                                       onFailure: failureHandler, onCancel: cancelHandler)
        } catch let error as NSError {
            Current.Log.error("Running shortcut failed \(error)")

            eventData["status"] = "error"
            eventData["error"] = error.localizedDescription

            Current.api.then { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }.catch { error -> Void in
                Current.Log.error("Received error from CallbackURLKit perform \(error)")
            }
        }
    }

}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // swiftlint:disable:next function_body_length
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if Current.appConfiguration == .FastlaneSnapshot &&
            response.actionIdentifier == UNNotificationDismissActionIdentifier &&
            response.notification.request.content.categoryIdentifier == "map" {
            SettingsViewController.showCameraContentExtension()
        }
        Messaging.messaging().appDidReceiveMessage(response.notification.request.content.userInfo)

        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else {
            Current.Log.info("ignoring dismiss action for notification")
            completionHandler()
            return
        }

        var userText: String?
        if let textInput = response as? UNTextInputNotificationResponse {
            userText = textInput.userText
        }
        let userInfo = response.notification.request.content.userInfo

        Current.Log.verbose("User info in incoming notification \(userInfo)")

        if let shortcutDict = userInfo["shortcut"] as? [String: String],
            let shortcutName = shortcutDict["name"] {

            self.handleShortcutNotification(shortcutName, shortcutDict)

        }

        if let openURLRaw = userInfo["url"] as? String {
            Current.sceneManager.webViewWindowControllerPromise.done { $0.open(urlString: openURLRaw) }
        } else if let openURLDictionary = userInfo["url"] as? [String: String] {
            let url = openURLDictionary.compactMap { key, value -> String? in
                if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
                    key.lowercased() == NotificationCategory.FallbackActionIdentifier {
                    return value
                } else if key.lowercased() == response.actionIdentifier.lowercased() {
                    return value
                } else {
                    return nil
                }
            }.first

            if let url = url {
                Current.sceneManager.webViewWindowControllerPromise.done { $0.open(urlString: url) }
            } else {
                Current.Log.error(
                    "couldn't make openable url out of \(openURLDictionary) for \(response.actionIdentifier)"
                )
            }
        } else if let someUrl = userInfo["url"] {
            Current.Log.error(
                "couldn't make openable url out of \(type(of: someUrl)): \(String(describing: someUrl))"
            )
        }

        Current.backgroundTask(withName: "handle-push-action") { _ in
            Current.api.then { api in
                api.handlePushAction(
                    identifier: response.actionIdentifier,
                    category: response.notification.request.content.categoryIdentifier,
                    userInfo: userInfo,
                    userInput: userText
                )
            }
        }.ensure {
            completionHandler()
        }.catch { err -> Void in
            Current.Log.error("Error when handling push action: \(err)")
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)

        if notification.request.content.userInfo[XCGLogger.notifyUserInfoKey] != nil,
            UIApplication.shared.applicationState != .background {
            completionHandler([])
            return
        }

        var methods: UNNotificationPresentationOptions = [.alert, .badge, .sound]
        if let presentationOptions = notification.request.content.userInfo["presentation_options"] as? [String] {
            methods = []
            if presentationOptions.contains("sound") || notification.request.content.sound != nil {
                methods.insert(.sound)
            }
            if presentationOptions.contains("badge") {
                methods.insert(.badge)
            }
            if presentationOptions.contains("alert") {
                methods.insert(.alert)
            }
        }
        return completionHandler(methods)
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        let view = NotificationSettingsViewController()
        view.doneButton = true

        Current.sceneManager.webViewWindowControllerPromise.done {
            var rootViewController = $0.window.rootViewController
            if let navigationController = rootViewController as? UINavigationController {
                rootViewController = navigationController.viewControllers.first
            }
            rootViewController?.dismiss(animated: false, completion: {
                let navController = UINavigationController(rootViewController: view)
                rootViewController?.present(navController, animated: true, completion: nil)
            })
        }
    }
}

extension NotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let loggableCurrent = Current.settingsStore.pushID ?? "(null)"
        let loggableNew = fcmToken ?? "(null)"

        Current.Log.info("Firebase registration token refreshed, new token: \(loggableNew)")

        if loggableCurrent != loggableNew {
            Current.Log.warning("FCM token has changed from \(loggableCurrent) to \(loggableNew)")
        }

        Current.crashReporter.setUserProperty(value: fcmToken, name: "FCM Token")
        Current.settingsStore.pushID = fcmToken

        Current.backgroundTask(withName: "notificationManager-didReceiveRegistrationToken") { _ in
            Current.api.then { api in
                api.UpdateRegistration()
            }
        }.cauterize()
    }
}
