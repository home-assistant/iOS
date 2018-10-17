//
//  AppDelegate.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import PromiseKit
import UserNotifications
import AlamofireNetworkActivityIndicator
import KeychainAccess
import Alamofire
import RealmSwift
import Shared
import SafariServices
import arek

let keychain = Keychain(service: "io.robbie.homeassistant")

let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var safariVC: SFSafariViewController?
    private(set) var regionManager: RegionManager!
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let launchingForLocation = launchOptions?[.location] != nil
        let launchMessage = "Application Starting" + (launchingForLocation ? " due to location change" : "")
        let event = ClientEvent(text: launchMessage, type: .unknown)
        Current.clientEventStore.addEvent(event)
        CheckPermissionsStatus()
        Current.deviceIDProvider = { DeviceUID.uid() }
        self.regionManager = RegionManager()

        Fabric.with([Crashlytics.self])

        Current.syncMonitoredRegions = { self.regionManager.syncMonitoredRegions() }
        if prefs.bool(forKey: "locationUpdateOnBackgroundFetch") {
            UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        }

        NetworkActivityIndicatorManager.shared.isEnabled = true
        if #available(iOS 10, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        setDefaults()

        window = UIWindow.init(frame: UIScreen.main.bounds)
        window?.backgroundColor = .white

        let webView = WebViewController()

        let navController = UINavigationController(rootViewController: webView)

        navController.setToolbarHidden(false, animated: false)
        navController.setNavigationBarHidden(true, animated: false)

        self.window!.rootViewController = navController
        self.window!.makeKeyAndVisible()
        if let tokenInfo = Current.settingsStore.tokenInfo,
            let connectionInfo = Current.settingsStore.connectionInfo {
            Current.tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: tokenInfo)
        }

        Current.authenticationControllerPresenter = { controller in
            if let presentedController = navController.topViewController?.presentedViewController {
                presentedController.present(controller, animated: true, completion: nil)
                return
            }

            navController.topViewController?.present(controller, animated: true, completion: nil)
        }

        Current.signInRequiredCallback = {
            let alert = UIAlertController(title: "You must sign in to continue",
                                          message: "The server has rejected your credentials, "
                                                  + "and you must sign in again to continue.",
                                          preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default,
                                          handler: { _ in
                                            navController.popToViewController(webView, animated: true)
                                            webView.showSettingsViewController()
            }))

            navController.present(alert, animated: true, completion: nil)
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {}

    func applicationDidEnterBackground(_ application: UIApplication) {}

    func applicationWillEnterForeground(_ application: UIApplication) {}

    func applicationDidBecomeActive(_ application: UIApplication) { CheckPermissionsStatus() }

    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return
        }

        let tokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})

        prefs.setValue(tokenString, forKey: "deviceToken")

        print("Registering push with tokenString: \(tokenString)")

        _ = api.registerDeviceForPush(deviceToken: tokenString).done { resp in
            if let pushId = resp.PushId {
                print("Registered for push. Platform: \(resp.SNSPlatform ?? "MISSING"), PushID: \(pushId)")
                CLSLogv("Registered for push %@:", getVaList([pushId]))
                Crashlytics.sharedInstance().setUserIdentifier(pushId)
                prefs.setValue(pushId, forKey: "pushID")
                Current.settingsStore.pushID = pushId
                _ = api.identifyDevice()
            }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Swift.Error) {
        print("Error when trying to register for push", error)
        Crashlytics.sharedInstance().recordError(error)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Received remote notification in completion handler!")
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            print("Remote notification handler failed because api was not authenticated")
            completionHandler(.failed)
            return
        }

        if let userInfoDict = userInfo as? [String: Any],
            let hadict = userInfoDict["homeassistant"] as? [String: String], let command = hadict["command"] {
                    switch command {
                    case "request_location_update":
                        if prefs.bool(forKey: "locationUpdateOnNotification") == false {
                            completionHandler(.noData)
                        }
                        print("Received remote request to provide a location update")
                        api.getAndSendLocation(trigger: .PushNotification).done { success in
                            print("Did successfully send location when requested via APNS?", success)
                            completionHandler(.newData)
                        }.catch {error in
                            print("Error when attempting to submit location update")
                            Crashlytics.sharedInstance().recordError(error)
                            completionHandler(.failed)
                        }
                    default:
                        print("Received unknown command via APNS!", userInfo)
                        completionHandler(.noData)
                    }
        } else {
            completionHandler(.failed)
        }
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            print("Background fetch failed because api was not authenticated")
            completionHandler(.failed)
            return
        }

        if prefs.bool(forKey: "locationUpdateOnBackgroundFetch") == false {
            completionHandler(UIBackgroundFetchResult.noData)
            return
        }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .full)
        print("Background fetch activated at \(timestamp)!")
        if Current.settingsStore.locationEnabled {
            api.getAndSendLocation(trigger: .BackgroundFetch).done { success in
                print("Sending location via background fetch")
                completionHandler(UIBackgroundFetchResult.newData)
            }.catch {error in
                print("Error when attempting to submit location update during background fetch")
                Crashlytics.sharedInstance().recordError(error)
                completionHandler(UIBackgroundFetchResult.failed)
            }
        } else {
            api.identifyDevice().done { _ in
                completionHandler(UIBackgroundFetchResult.newData)
            }.catch {error in
                print("Error when attempting to identify device during background fetch")
                Crashlytics.sharedInstance().recordError(error)
                completionHandler(UIBackgroundFetchResult.failed)
            }
        }
    }

    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?,
                     forRemoteNotification userInfo: [AnyHashable: Any],
                     withResponseInfo responseInfo: [AnyHashable: Any],
                     completionHandler: @escaping () -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            print("Notifcation action failed because api was not authenticated")
            completionHandler()
            return
        }

        var userInput: String?
        if let userText = responseInfo[UIUserNotificationActionResponseTypedTextKey] as? String {
            userInput = userText
        }

        _ = api.handlePushAction(identifier: identifier!, userInfo: userInfo, userInput: userInput).ensure {
            completionHandler()
        }
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        var serviceData: [String: String] = [:]
        if let queryItems = url.queryItems {
            serviceData = queryItems
        }
        switch url.host! {
        case "call_service":
            callServiceURLHAndler(url, serviceData)
        case "fire_event":
            fireEventURLHandler(url, serviceData)
        case "send_location":
            sendLocationURLHandler()
        case "auth-callback": // homeassistant://auth-callback
           NotificationCenter.default.post(name: Notification.Name("AuthCallback"), object: nil,
                                           userInfo: ["url": url])
        default:
            print("Can't route", url.host!)
            showAlert(title: L10n.UrlHandler.Error.title,
                      message: L10n.UrlHandler.NoService.message(url.host!))
        }
        return true
    }

    // MARK: - Private helpers

    private func fireEventURLHandler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity
        _ = firstly {
            HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.createEvent(eventType: url.pathComponents[1], eventData: serviceData)
            }.done { _ in
                showAlert(title: L10n.UrlHandler.FireEvent.Success.title,
                          message: L10n.UrlHandler.FireEvent.Success.message(url.pathComponents[1]))
            }.catch { error -> Void in
                showAlert(title: L10n.UrlHandler.Error.title,
                          message: L10n.UrlHandler.FireEvent.Error.message(url.pathComponents[1],
                                                                           error.localizedDescription))
        }
    }

    private func callServiceURLHAndler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
        let domain = url.pathComponents[1].components(separatedBy: ".")[0]
        let service = url.pathComponents[1].components(separatedBy: ".")[1]
        _ = firstly {
            HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.callService(domain: domain, service: service, serviceData: serviceData)
            }.done { _ in
                showAlert(title: L10n.UrlHandler.CallService.Success.title,
                          message: L10n.UrlHandler.CallService.Success.message(url.pathComponents[1]))
            }.catch { error in
                showAlert(title: L10n.UrlHandler.Error.title,
                          message: L10n.UrlHandler.CallService.Error.message(url.pathComponents[1],
                                                                             error.localizedDescription))
        }
    }

    private func sendLocationURLHandler() {
        // homeassistant://send_location/
        _ = firstly {
            HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.getAndSendLocation(trigger: .URLScheme)
            }.done { _ in
                showAlert(title: L10n.UrlHandler.SendLocation.Success.title,
                          message: L10n.UrlHandler.SendLocation.Success.message)
            }.catch { error in
                showAlert(title: L10n.UrlHandler.Error.title,
                          message: L10n.UrlHandler.SendLocation.Error.message(error.localizedDescription))
        }
    }
}

@available(iOS 10, *)
extension AppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        var userText: String?
        if let textInput = response as? UNTextInputNotificationResponse {
            userText = textInput.userText
        }
        let userInfo = response.notification.request.content.userInfo
        if let openUrl = userInfo["url"] as? String,
            let url = URL(string: openUrl) {
            if prefs.bool(forKey: "confirmBeforeOpeningUrl") {
                let alert = UIAlertController(title: L10n.Alerts.OpenUrlFromNotification.title,
                                              message: L10n.Alerts.OpenUrlFromNotification.message(openUrl),
                                              preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: L10n.noLabel, style: UIAlertActionStyle.default, handler: nil))
                alert.addAction(UIAlertAction(title: L10n.yesLabel, style: UIAlertActionStyle.default, handler: { _ in
                    UIApplication.shared.open(url, options: [:],
                                              completionHandler: nil)
                }))
                var rootViewController = UIApplication.shared.keyWindow?.rootViewController
                if let navigationController = rootViewController as? UINavigationController {
                    rootViewController = navigationController.viewControllers.first
                }
                if let tabBarController = rootViewController as? UITabBarController {
                    rootViewController = tabBarController.selectedViewController
                }
                rootViewController?.present(alert, animated: true, completion: nil)
            } else {
                UIApplication.shared.open(url, options: [:],
                                          completionHandler: nil)
            }
        }
        firstly {
            HomeAssistantAPI.authenticatedAPIPromise
        }.then { api in
            api.handlePushAction(identifier: response.actionIdentifier, userInfo: userInfo,
                                 userInput: userText)
        }.ensure {
            completionHandler()
        }.catch { err -> Void in
            print("Error: \(err)")
            Crashlytics.sharedInstance().recordError(err)
        }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       // swiftlint:disable:next line_length
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
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
}
