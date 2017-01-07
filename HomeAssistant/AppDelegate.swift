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
import RealmSwift
import UserNotifications
import AlamofireNetworkActivityIndicator

let realmConfig = Realm.Configuration(schemaVersion: 2, migrationBlock: nil)

// swiftlint:disable:next force_try
let realm = try! Realm(configuration: realmConfig)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    let prefs = UserDefaults(suiteName: "group.io.robbie.homeassistant")!

    // swiftlint:disable:next line_length
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]? = nil) -> Bool {
        migrateUserDefaultsToAppGroups()
        Realm.Configuration.defaultConfiguration = realmConfig
        print("Realm file path", Realm.Configuration.defaultConfiguration.fileURL!.path)
        Fabric.with([Crashlytics.self])

        NetworkActivityIndicatorManager.shared.isEnabled = true

        if #available(iOS 10, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        Crashlytics.sharedInstance().setObjectValue(prefs.integer(forKey: "lastInstalledVersion"),
                                                    forKey: "lastInstalledVersion")
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") {
            if let stringedBundleVersion = bundleVersion as? String {
                prefs.set(stringedBundleVersion, forKey: "lastInstalledVersion")
            }
        }

        initAPI()

        return true
    }

    func initAPI() {
        if let baseURL = prefs.string(forKey: "baseURL") {
            print("Base URL is", baseURL)
            var apiPass = ""
            if let pass = prefs.string(forKey: "apiPassword") {
                apiPass = pass
            }
            firstly {
                HomeAssistantAPI.sharedInstance.Setup(baseAPIUrl: baseURL, APIPassword: apiPass)
                }.then {_ in
                    HomeAssistantAPI.sharedInstance.Connect()
                }.then { _ -> Void in
                    if HomeAssistantAPI.sharedInstance.notificationsEnabled {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    print("Connected!")
                    return
                }.catch {err -> Void in
                    print("ERROR", err)
                    let settingsView = SettingsViewController()
                    settingsView.title = "Settings"
                    settingsView.showErrorConnectingMessage = true
                    let navController = UINavigationController(rootViewController: settingsView)
                    self.window?.makeKeyAndVisible()
                    self.window?.rootViewController!.present(navController, animated: true, completion: nil)
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {}

    func applicationDidEnterBackground(_ application: UIApplication) {}

    func applicationWillEnterForeground(_ application: UIApplication) {}

    func applicationDidBecomeActive(_ application: UIApplication) {}

    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        let tokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})

        self.prefs.setValue(tokenString, forKey: "deviceToken")

        print("Registering push with tokenString: \(tokenString)")

        _ = HomeAssistantAPI.sharedInstance.registerDeviceForPush(deviceToken: tokenString).then { pushId -> Void in
            print("Registered for push. PushID:", pushId)
            CLSLogv("Registered for push:", getVaList([pushId]))
            Crashlytics.sharedInstance().setUserIdentifier(pushId)
            self.prefs.setValue(pushId, forKey: "pushID")
        }

    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Swift.Error) {
        print("Error when trying to register for push", error)
        Crashlytics.sharedInstance().recordError(error)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Received remote notification in completion handler!")

        if let userInfoDict = userInfo as? [String:Any] {
            if let hadict = userInfoDict["homeassistant"] as? [String:String] {
                if let command = hadict["command"] {
                    switch command {
                    case "request_location_update":
                        print("Received remote request to provide a location update")
                        HomeAssistantAPI.sharedInstance.sendOneshotLocation().then { success -> Void in
                            print("Did successfully send location when requested via APNS?", success)
                            completionHandler(UIBackgroundFetchResult.noData)
                            }.catch {error in
                                print("Error when attempting to submit location update")
                                Crashlytics.sharedInstance().recordError(error)
                                completionHandler(UIBackgroundFetchResult.failed)
                        }
                    default:
                        print("Received unknown command via APNS!", userInfo)
                        completionHandler(UIBackgroundFetchResult.noData)
                    }
                }
            }
        }
    }

    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?,
                     forRemoteNotification userInfo: [AnyHashable : Any],
                     withResponseInfo responseInfo: [AnyHashable : Any],
                     completionHandler: @escaping () -> Void) {
        var userInput: String? = nil
        if let userText = responseInfo[UIUserNotificationActionResponseTypedTextKey] as? String {
            userInput = userText
        }
        let _ = HomeAssistantAPI.sharedInstance.handlePushAction(identifier: identifier!,
                                                                 userInfo: userInfo,
                                                                 userInput: userInput)
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        var serviceData: [String:String] = url.queryItems!
        serviceData["sourceApplication"] = options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String
        switch url.host! {
        case "call_service": // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
            let domain = url.pathComponents[1].components(separatedBy: ".")[0]
            let service = url.pathComponents[1].components(separatedBy: ".")[1]
            let _ = HomeAssistantAPI.sharedInstance.CallService(domain: domain,
                                                                service: service,
                                                                serviceData: serviceData)
            break
        case "fire_event": // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity
            let _ = HomeAssistantAPI.sharedInstance.CreateEvent(eventType: url.pathComponents[1],
                                                                eventData: serviceData)
            break
        case "send_location": // homeassistant://send_location/
            let _ = HomeAssistantAPI.sharedInstance.sendOneshotLocation()
            break
        default:
            print("Can't route", url.host!)
        }
        return true
    }
}

@available(iOS 10, *)
extension AppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        var userText: String? = nil
        if let textInput = response as? UNTextInputNotificationResponse {
            userText = textInput.userText
        }
        HomeAssistantAPI.sharedInstance.handlePushAction(identifier: response.actionIdentifier,
                                                         userInfo: response.notification.request.content.userInfo,
                                                         userInput: userText).then { _ in
                                                            completionHandler()
            }.catch { err -> Void in
                print("Error: \(err)")
                Crashlytics.sharedInstance().recordError(err)
                completionHandler()
        }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       // swiftlint:disable:next line_length
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
}
