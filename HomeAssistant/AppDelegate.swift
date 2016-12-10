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

let realmConfig = Realm.Configuration(
    schemaVersion: 2,
    
    migrationBlock: { migration, oldSchemaVersion in
        if (oldSchemaVersion < 1) {
        }
})

let realm = try! Realm(configuration: realmConfig)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    let prefs = UserDefaults(suiteName: "group.io.robbie.homeassistant")!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        migrateUserDefaultsToAppGroups()
        Realm.Configuration.defaultConfiguration = realmConfig
        print("Realm file path", Realm.Configuration.defaultConfiguration.fileURL!.path)
        Fabric.with([Crashlytics.self])
        
        NetworkActivityIndicatorManager.shared.isEnabled = true
        
        if #available(iOS 10, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        
        Crashlytics.sharedInstance().setObjectValue(prefs.integer(forKey: "lastInstalledVersion"), forKey: "lastInstalledVersion")
        let buildNumber = Int(string: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")! as! String)
        prefs.set(buildNumber, forKey: "lastInstalledVersion")
        
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
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        
        self.prefs.setValue(deviceTokenString, forKey: "deviceToken")
        
        print("Registering push with deviceTokenString: \(deviceTokenString)")
        
        _ = HomeAssistantAPI.sharedInstance.registerDeviceForPush(deviceToken: deviceTokenString).then { pushId -> Void in
            print("Registered for push. PushID:", pushId)
            CLSLogv("Registered for push:", getVaList([pushId]))
            Crashlytics.sharedInstance().setUserIdentifier(pushId)
            self.prefs.setValue(pushId, forKey: "pushID")
        }
        
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Swift.Error) {
        print("Error when trying to register for push", error)
        Crashlytics.sharedInstance().recordError(error)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Received remote notification in completion handler!")
        
        let userInfoDict = userInfo as! [String:Any]
        
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
                        Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
                        completionHandler(UIBackgroundFetchResult.failed)
                    }
                default:
                    print("Received unknown command via APNS!", userInfo)
                    completionHandler(UIBackgroundFetchResult.noData)
                }
            }
        }
    }
    
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], withResponseInfo responseInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
        var userInput:String? = nil
        if let userText = responseInfo[UIUserNotificationActionResponseTypedTextKey] as? String {
            userInput = userText
        }
        let _ = HomeAssistantAPI.sharedInstance.handlePushAction(identifier: identifier!, userInfo: userInfo, userInput: userInput)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        var serviceData : [String:String] = url.queryItems!
        serviceData["sourceApplication"] = options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String
        switch url.host! {
        case "call_service": // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
            let _ = HomeAssistantAPI.sharedInstance.CallService(domain: url.pathComponents[1].components(separatedBy: ".")[0], service: url.pathComponents[1].components(separatedBy: ".")[1], serviceData: serviceData)
            break
        case "fire_event": // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity
            let _ = HomeAssistantAPI.sharedInstance.CreateEvent(eventType: url.pathComponents[1], eventData: serviceData)
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
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        var userText : String? = nil
        if let textInput = response as? UNTextInputNotificationResponse {
            userText = textInput.userText
        }
        HomeAssistantAPI.sharedInstance.handlePushAction(identifier: response.actionIdentifier, userInfo: response.notification.request.content.userInfo, userInput: userText).then { _ in
            completionHandler()
        }.catch { err -> Void in
            print("Error: \(err)")
            Crashlytics.sharedInstance().recordError(err)
            completionHandler()
        }
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
}
