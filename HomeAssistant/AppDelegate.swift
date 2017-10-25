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
import SwiftLocation

let keychain = Keychain(service: "io.robbie.homeassistant")

let prefs = UserDefaults(suiteName: "group.io.robbie.homeassistant")!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Fabric.with([Crashlytics.self])

        HomeAssistantAPI.sharedInstance.Setup(baseURLString: keychain["baseURL"], password: keychain["apiPassword"],
                                              deviceID: keychain["deviceID"])

        if launchOptions?[UIApplicationLaunchOptionsKey.location] != nil {
            resumeRegionMonitoring()
        }

        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)

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

        if prefs.object(forKey: "openInChrome") == nil && OpenInChromeController().isChromeInstalled() {
            prefs.setValue(true, forKey: "openInChrome")
            prefs.synchronize()
        }

        registerForSignificantLocationUpdates()

        window = UIWindow.init(frame: UIScreen.main.bounds)
        window?.backgroundColor = .white

        let webView = WebViewController()

        let navController = UINavigationController(rootViewController: webView)

        navController.setToolbarHidden(false, animated: false)
        navController.setNavigationBarHidden(true, animated: false)

        self.window!.rootViewController = navController
        self.window!.makeKeyAndVisible()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {}

    func applicationDidEnterBackground(_ application: UIApplication) {}

    func applicationWillEnterForeground(_ application: UIApplication) {}

    func applicationDidBecomeActive(_ application: UIApplication) {}

    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        let tokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})

        prefs.setValue(tokenString, forKey: "deviceToken")

        print("Registering push with tokenString: \(tokenString)")

        _ = HomeAssistantAPI.sharedInstance.RegisterDeviceForPush(deviceToken: tokenString).then { resp -> Void in
            if let pushId = resp.PushId {
                print("Registered for push. Platform: \(resp.SNSPlatform ?? "MISSING"), PushID: \(pushId)")
                CLSLogv("Registered for push:", getVaList([pushId]))
                Crashlytics.sharedInstance().setUserIdentifier(pushId)
                prefs.setValue(pushId, forKey: "pushID")
                HomeAssistantAPI.sharedInstance.pushID = pushId
                _ = HomeAssistantAPI.sharedInstance.IdentifyDevice()
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

        HomeAssistantAPI.sharedInstance.Setup(baseURLString: keychain["baseURL"], password: keychain["apiPassword"],
                                              deviceID: keychain["deviceID"])

        if let userInfoDict = userInfo as? [String: Any] {
            if let hadict = userInfoDict["homeassistant"] as? [String: String] {
                if let command = hadict["command"] {
                    switch command {
                    case "request_location_update":
                        print("Received remote request to provide a location update")
                        HomeAssistantAPI.sharedInstance.sendOneshotLocation().then { success -> Void in
                            print("Did successfully send location when requested via APNS?", success)
                            if success == true {
                                completionHandler(UIBackgroundFetchResult.newData)
                            } else {
                                completionHandler(UIBackgroundFetchResult.failed)
                            }
                        }.catch {error in
                            print("Error when attempting to submit location update")
                            Crashlytics.sharedInstance().recordError(error)
                            completionHandler(UIBackgroundFetchResult.failed)
                        }
                    default:
                        print("Received unknown command via APNS!", userInfo)
                        completionHandler(UIBackgroundFetchResult.noData)
                    }
                } else {
                    completionHandler(UIBackgroundFetchResult.failed)
                }
            } else {
                completionHandler(UIBackgroundFetchResult.failed)
            }
        } else {
            completionHandler(UIBackgroundFetchResult.failed)
        }
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        print("Background fetch activated at \(timestamp)!")
        HomeAssistantAPI.sharedInstance.Setup(baseURLString: keychain["baseURL"], password: keychain["apiPassword"],
                                              deviceID: keychain["deviceID"])
        if HomeAssistantAPI.sharedInstance.locationEnabled {
            HomeAssistantAPI.sharedInstance.getAndSendLocation(trigger: .BackgroundFetch).then { success -> Void in
                if success == true {
                    completionHandler(UIBackgroundFetchResult.newData)
                } else {
                    completionHandler(UIBackgroundFetchResult.failed)
                }
                }.catch {error in
                    print("Error when attempting to submit location update during background fetch")
                    Crashlytics.sharedInstance().recordError(error)
                    completionHandler(UIBackgroundFetchResult.failed)
            }
        } else {
            HomeAssistantAPI.sharedInstance.IdentifyDevice().then { _ -> Void in
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
        HomeAssistantAPI.sharedInstance.Setup(baseURLString: keychain["baseURL"], password: keychain["apiPassword"],
                                              deviceID: keychain["deviceID"])
        var userInput: String?
        if let userText = responseInfo[UIUserNotificationActionResponseTypedTextKey] as? String {
            userInput = userText
        }
        _ = HomeAssistantAPI.sharedInstance.handlePushAction(identifier: identifier!,
                                                             userInfo: userInfo,
                                                             userInput: userInput)
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        HomeAssistantAPI.sharedInstance.Setup(baseURLString: keychain["baseURL"], password: keychain["apiPassword"],
                                              deviceID: keychain["deviceID"])
        var serviceData: [String: String] = url.queryItems!
        serviceData["sourceApplication"] = options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String
        switch url.host! {
        case "call_service": // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
            let domain = url.pathComponents[1].components(separatedBy: ".")[0]
            let service = url.pathComponents[1].components(separatedBy: ".")[1]
            _ = HomeAssistantAPI.sharedInstance.CallService(domain: domain,
                                                            service: service,
                                                            serviceData: serviceData)
        case "fire_event": // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity
            _ = HomeAssistantAPI.sharedInstance.CreateEvent(eventType: url.pathComponents[1],
                                                            eventData: serviceData)
        case "send_location": // homeassistant://send_location/
            _ = HomeAssistantAPI.sharedInstance.sendOneshotLocation()
        default:
            print("Can't route", url.host!)
        }
        return true
    }

    func registerForSignificantLocationUpdates() {
        if HomeAssistantAPI.sharedInstance.locationEnabled {
            Location.getLocation(accuracy: .neighborhood, frequency: .significant, timeout: nil,
                                 success: { (_, location) -> Void in

                                HomeAssistantAPI.sharedInstance.Setup(baseURLString: keychain["baseURL"],
                                                                      password: keychain["apiPassword"],
                                                                      deviceID: keychain["deviceID"])

                                HomeAssistantAPI.sharedInstance.submitLocation(updateType: .SignificantLocationUpdate,
                                                                               coordinates: location.coordinate,
                                                                               accuracy: location.horizontalAccuracy,
                                                                               zone: nil)
            }) { (_, _, error) -> Void in
                // something went wrong. request will be cancelled automatically
                NSLog("Something went wrong when trying to get significant location updates! Error was: @%",
                      error.localizedDescription)
                Crashlytics.sharedInstance().recordError(error)
            }
        }
    }

    func resumeRegionMonitoring() {
        if HomeAssistantAPI.sharedInstance.locationEnabled {
            HomeAssistantAPI.sharedInstance.Setup(baseURLString: keychain["baseURL"], password: keychain["apiPassword"],
                                                  deviceID: keychain["deviceID"])

            HomeAssistantAPI.sharedInstance.beaconManager.resumeScanning()
        }
    }

}

@available(iOS 10, *)
extension AppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        HomeAssistantAPI.sharedInstance.Setup(baseURLString: keychain["baseURL"], password: keychain["apiPassword"],
                                              deviceID: keychain["deviceID"])
        var userText: String?
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
        print("Received notification!")
        return completionHandler([.alert, .badge, .sound])
    }
}
