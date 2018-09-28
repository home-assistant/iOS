//
//  ExtensionDelegate.swift
//  WatchApp Extension
//
//  Created by Robert Trencheny on 9/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import WatchKit
import WatchConnectivity
import ClockKit
import RealmSwift

class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate {

    // Our WatchConnectivity Session for communicating with the iOS app
    var watchSession: WCSession?

    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("Received context!", applicationContext)

        if let refs = applicationContext["complications"] as? [ThreadSafeReference<WatchComplication>] {
            print("Received latest complication configurations!", refs)
            let realm = Realm.live()

            for ref in refs {
                guard let complicationConfig = realm.resolve(ref) else {
                    print("Unable to resolve Realm ThreadSafeReference, maybe config was deleted?")
                    return
                }

                // swiftlint:disable:next force_try
                try! realm.write {
                    realm.add(complicationConfig, update: true)
                }
            }
        } else {
            print("Unable to cast complication refs!!!", applicationContext)
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        watchSession = session
        print("Session did activate", session)

        updateApplicationContext()
    }

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        print("didFinishLaunching")
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
        // If the application was previously in the background, optionally refresh the user interface.

        print("didBecomeActive")

        if watchSession == nil && WCSession.isSupported() {
            watchSession = WCSession.default
            watchSession!.delegate = self
            watchSession!.activate()
        }

        updateApplicationContext()
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state.
        // This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message)
        // or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        print("willResignActive")
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks.
        // Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true,
                                              estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    func updateApplicationContext() {
        guard let watchSession = watchSession, watchSession.activationState == .activated else {
            print("Session not available or active, not updating context!")
            return
        }

        var activeFamilies: [String] = []

        if let activeComplications = CLKComplicationServer.sharedInstance().activeComplications {
            activeFamilies = activeComplications.map({
                return ComplicationGroupMember(family: $0.family).rawValue
            })
        }

        print("active families", activeFamilies)

        print("applicationContext PRE", watchSession.applicationContext)

        do {
            try watchSession.updateApplicationContext(["activeComplications": activeFamilies])
        } catch let error as NSError {
            print("Updating the context failed: ", error.localizedDescription)
        }

        print("applicationContext POST", watchSession.applicationContext)
    }

}
