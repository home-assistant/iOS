//
//  AppDelegate.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import AWSSNS
import Fabric
import Crashlytics
import DeviceKit
import PromiseKit
import RealmSwift
import UserNotifications

let realmConfig = Realm.Configuration(
    schemaVersion: 1,
    
    migrationBlock: { migration, oldSchemaVersion in
        if (oldSchemaVersion < 1) {
        }
})

let realm = try! Realm(configuration: realmConfig)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    let prefs = UserDefaults.standard
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        Realm.Configuration.defaultConfiguration = realmConfig
        print("Realm file path", Realm.Configuration.defaultConfiguration.fileURL!.absoluteString)
        Fabric.with([Crashlytics.self])
        
        AWSLogger.default().logLevel = .info
        
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.usEast1, identityPoolId:"us-east-1:2b1692f3-c9d3-4d81-b7e9-83cd084f3a59")
        
        let configuration = AWSServiceConfiguration(region:.usWest2, credentialsProvider:credentialsProvider)
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = NotificationManager()
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
        
        print("Registering with deviceTokenString: \(deviceTokenString)")
        
        let sns = AWSSNS.default()
        let request = AWSSNSCreatePlatformEndpointInput()
        request?.token = deviceTokenString
        request?.platformApplicationArn = "arn:aws:sns:us-west-2:663692594824:app/APNS_SANDBOX/HomeAssistant"
        sns.createPlatformEndpoint(request!).continue({ (task: AWSTask!) -> Any? in
            if task.error != nil {
                print("Error: \(task.error)")
                Crashlytics.sharedInstance().recordError(task.error!)
            } else {
                let createEndpointResponse = task.result!
                print("endpointArn:", createEndpointResponse.endpointArn!)
                Crashlytics.sharedInstance().setUserIdentifier(createEndpointResponse.endpointArn!.components(separatedBy: "/").last!)
                self.prefs.setValue(createEndpointResponse.endpointArn!, forKey: "endpointARN")
                self.prefs.setValue(deviceTokenString, forKey: "deviceToken")
                let subrequest = try! AWSSNSSubscribeInput(dictionary: [
                    "topicArn": "arn:aws:sns:us-west-2:663692594824:HomeAssistantiOSBetaTesters",
                    "endpoint": createEndpointResponse.endpointArn,
                    "protocols": "application"
                ], error: ())
                sns.subscribe(subrequest).continue ({ (subTask: AWSTask!) -> AnyObject! in
                    if subTask.error != nil {
                        print("Error: \(subTask.error)")
                        Crashlytics.sharedInstance().recordError(subTask.error!)
                    } else {
                        print("Subscribed endpoint to broadcast topic")
                    }
                    
                    return nil
                })
            }
            
            return nil
        })
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
                    HomeAssistantAPI.sharedInstance.sendOneshotLocation(notifyString: "").then { success -> Void in
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
        print("Action button hit", identifier)
        print("Remote notification payload", userInfo)
        print("ResponseInfo", responseInfo)
        let device = Device()
        var eventData : [String:Any] = ["actionName": identifier! as AnyObject, "sourceDevicePermanentID": DeviceUID.uid() as AnyObject, "sourceDeviceName": device.name as AnyObject]
        if let dataDict = userInfo["homeassistant"] {
            eventData["action_data"] = dataDict
        }
        if !responseInfo.isEmpty {
            eventData["response_info"] = responseInfo
        }
        HomeAssistantAPI.sharedInstance.CreateEvent(eventType: "ios.notification_action_fired", eventData: eventData).then { _ in
            completionHandler()
            }.catch {error in
                Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
                completionHandler()
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        var serviceData : [String:String] = url.queryItems!
        serviceData["sourceApplication"] = options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String
        switch url.host! {
        case "call_service": // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
            let _ = HomeAssistantAPI.sharedInstance.CallService(domain: EntityIDToDomainTransform().transformFromJSON(url.pathComponents[1])!, service: url.pathComponents[1].components(separatedBy: ".")[1], serviceData: serviceData)
            break
        case "fire_event": // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity
            let _ = HomeAssistantAPI.sharedInstance.CreateEvent(eventType: url.pathComponents[1], eventData: serviceData)
            break
        default:
            print("Can't route", url.host)
        }
        return true
    }
}

