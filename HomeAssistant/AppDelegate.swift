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
import PermissionScope
import DeviceKit
import PromiseKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    let prefs = NSUserDefaults.standardUserDefaults()
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        Fabric.with([Crashlytics.self])
        
        AWSLogger.defaultLogger().logLevel = .Info
        
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast1, identityPoolId:"us-east-1:2b1692f3-c9d3-4d81-b7e9-83cd084f3a59")
        
        let configuration = AWSServiceConfiguration(region:.USWest2, credentialsProvider:credentialsProvider)
        
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration

        initAPI()
        
        return true
    }
    
    func initAPI() {
        if let baseURL = prefs.stringForKey("baseURL") {
            print("Base URL is", baseURL)
            var apiPass = ""
            if let pass = prefs.stringForKey("apiPassword") {
                apiPass = pass
            }
            firstly {
                HomeAssistantAPI.sharedInstance.Setup(baseURL, APIPassword: apiPass)
            }.then {_ in 
                HomeAssistantAPI.sharedInstance.Connect()
            }.error { err -> Void in
                print("ERROR", err)
                let settingsView = SettingsViewController()
                settingsView.title = "Settings"
                settingsView.showErrorConnectingMessage = true
                let navController = UINavigationController(rootViewController: settingsView)
                self.window?.makeKeyAndVisible()
                self.window?.rootViewController!.presentViewController(navController, animated: true, completion: nil)
            }
        }
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        let deviceTokenString = "\(deviceToken)"
            .stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString:"<>"))
            .stringByReplacingOccurrencesOfString(" ", withString: "")
        print("Registering with deviceTokenString: \(deviceTokenString)")
        
        let sns = AWSSNS.defaultSNS()
        let request = AWSSNSCreatePlatformEndpointInput()
        request.token = deviceTokenString
        request.platformApplicationArn = "arn:aws:sns:us-west-2:663692594824:app/APNS/HomeAssistant"
        sns.createPlatformEndpoint(request).continueWithBlock { (task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                print("Error: \(task.error)")
                Crashlytics.sharedInstance().recordError(task.error!)
            } else {
                let createEndpointResponse = task.result as! AWSSNSCreateEndpointResponse
                print("endpointArn:", createEndpointResponse.endpointArn!)
                Crashlytics.sharedInstance().setUserIdentifier(createEndpointResponse.endpointArn!.componentsSeparatedByString("/").last!)
                self.prefs.setValue(createEndpointResponse.endpointArn!, forKey: "endpointARN")
                self.prefs.setValue(deviceTokenString, forKey: "deviceToken")
                let subrequest = AWSSNSSubscribeInput()
                subrequest.topicArn = "arn:aws:sns:us-west-2:663692594824:HomeAssistantiOSBetaTesters"
                subrequest.endpoint = createEndpointResponse.endpointArn
                subrequest.protocols = "application"
                sns.subscribe(subrequest).continueWithBlock { (subTask: AWSTask!) -> AnyObject! in
                    if subTask.error != nil {
                        print("Error: \(subTask.error)")
                        Crashlytics.sharedInstance().recordError(subTask.error!)
                    } else {
                        print("Subscribed endpoint to broadcast topic")
                    }
                    
                    return nil
                }
            }
            
            return nil
        }
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        print("Error when trying to register for push", error)
        Crashlytics.sharedInstance().recordError(error)
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        print("Received remote notification!", userInfo)
    }
    
    func application(application: UIApplication,  didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        print("Received remote notification in completion handler!", userInfo)
        completionHandler(UIBackgroundFetchResult.NoData)
    }
    
    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [NSObject : AnyObject], withResponseInfo responseInfo: [NSObject : AnyObject], completionHandler: () -> Void) {
        print("Action button hit", identifier)
        print("Remote notification payload", userInfo)
        print("ResponseInfo", responseInfo)
        let device = Device()
        var eventData : [String:AnyObject] = ["actionName": identifier!, "sourceDevicePermanentID": DeviceUID.uid(), "sourceDeviceName": device.name]
        if let dataDict = userInfo["homeassistant"] {
            eventData["action_data"] = dataDict
        }
        if !responseInfo.isEmpty {
            eventData["response_info"] = responseInfo
        }
        HomeAssistantAPI.sharedInstance.CreateEvent("ios.notification_action_fired", eventData: eventData).then { _ in
            completionHandler()
        }.error { error in
            Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
            completionHandler()
        }
    }
    
    func application(application: UIApplication, openURL url: NSURL, options: [String: AnyObject]) -> Bool {
        var serviceData = [String:AnyObject]()
        for (k,v) in url.queryDictionary! {
            serviceData[k] = v
        }
        for (k,v) in options {
            serviceData[k] = v
        }
        switch url.host! {
        case "call_service": // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
            HomeAssistantAPI.sharedInstance.CallService(getEntityType(url.pathComponents![1]), service: url.pathComponents![1].componentsSeparatedByString(".")[1], serviceData: serviceData)
            break
        case "fire_event": // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity
            HomeAssistantAPI.sharedInstance.CreateEvent(url.pathComponents![1], eventData: serviceData)
            break
        default:
            print("Can't route", url.host)
        }
        return true
    }
}

