//
//  ExtensionDelegate.swift
//  WatchApp Extension
//
//  Created by Robert Trencheny on 9/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import WatchKit
import ClockKit
import RealmSwift
import Communicator
import UserNotifications

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    // MARK: - Properties -
    // MARK: Fileprivate

    fileprivate var watchConnectivityTask: WKWatchConnectivityRefreshBackgroundTask? {
        didSet {
            print("watchConnectivityTask set")
            oldValue?.setTaskCompleted()
        }
    }

    // MARK: - WKExtensionDelegate -

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        print("didFinishLaunching")

        setupWatchCommunicator()
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
        // If the application was previously in the background, optionally refresh the user interface.

        print("didBecomeActive")
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
                watchConnectivityTask = connectivityTask
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

    // Triggered when a complication is tapped
    func handleUserActivity(_ userInfo: [AnyHashable: Any]?) {

        if let date = userInfo?[CLKLaunchedTimelineEntryDateKey] as? Date {

            if let family = date.complicationFamilyFromEncodedDate {
                print("\(family.description) complication opened app")
            }
        }
    }

    func updateApplicationContext() {
        var activeFamilies: [String] = []

        if let activeComplications = CLKComplicationServer.sharedInstance().activeComplications {
            activeFamilies = activeComplications.map({
                return ComplicationGroupMember(family: $0.family).rawValue
            })
        }

        print("active families", activeFamilies)

        let context = Context(content: ["activeComplications": activeFamilies, "model": getModelName()])

//        let content = UNMutableNotificationContent()
//        content.title = "Context"
//        content.body = context.content.debugDescription
//        content.sound = UNNotificationSound.default
//
//        let notificationRequest =
//            UNNotificationRequest.init(identifier: "context",
//                                       content: content, trigger: nil)
//        UNUserNotificationCenter.current().add(notificationRequest)

        do {
            try Communicator.shared.sync(context: context)
        } catch let error as NSError {
            print("Updating the context failed: ", error.localizedDescription)
        }

        print("Set the context")
    }

    func setupWatchCommunicator() {
        Communicator.shared.activationStateChangedObservers.add { state in
            print("Activation state changed: ", state)

            self.updateApplicationContext()
        }

        Communicator.shared.reachabilityChangedObservers.add { reachability in
            print("Reachability changed: ", reachability)

            self.updateApplicationContext()
        }

        Communicator.shared.immediateMessageReceivedObservers.add { message in
            print("Received message: ", message.identifier)

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.guaranteedMessageReceivedObservers.add { message in
            let realm = Realm.live()

            if message.identifier == "actions" {
                let content = message.content

                if let actionJSONs = content["data"]! as? [[String: Any]] {
                    // swiftlint:disable:next force_try
                    try! realm.write {
                        for actionJSON in actionJSONs {
                            if let action = Action(JSON: actionJSON) {
                                print("ACTION", action)
                                realm.add(action, update: true)
                            }
                        }
                    }
                }
            }
        }

        Communicator.shared.blobReceivedObservers.add { blob in
            print("Received blob: ", blob.identifier)

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.contextUpdatedObservers.add { context in
            print("Received context: ", context)
            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.complicationInfoReceivedObservers.add { complicationInfo in
            print("Received complication info: ", complicationInfo)

            self.updateApplicationContext()

            let realm = Realm.live()

            for (family, data) in complicationInfo.content {
                print("Family", family)
                print("Data", data)

                if let dataDict = data as? [String: Any], let complicationConfig = WatchComplication(JSON: dataDict) {
                    // swiftlint:disable:next force_try
                    try! realm.write {
                        print("Writing", complicationConfig.Family)
                        realm.add(complicationConfig, update: true)
                    }
                }
            }

            CLKComplicationServer.sharedInstance().activeComplications?.forEach {
                CLKComplicationServer.sharedInstance().reloadTimeline(for: $0)
            }
            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }
    }

    private func endWatchConnectivityBackgroundTaskIfNecessary() {
        // First check we're not expecting more data
        guard !Communicator.shared.hasPendingDataToBeReceived else { return }
        // And then end the task (if there is one!)
        self.watchConnectivityTask?.setTaskCompleted()
    }

}

func getModelName() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return identifier
}
