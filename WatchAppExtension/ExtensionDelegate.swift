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
import XCGLogger
import Shared
import PromiseKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    // MARK: - Properties -

    var urlIdentifier: String?
    var bgTask: WKRefreshBackgroundTask?

    // MARK: Fileprivate

    fileprivate var watchConnectivityTask: WKWatchConnectivityRefreshBackgroundTask? {
        didSet {
            oldValue?.setTaskCompleted()
        }
    }

    // MARK: - WKExtensionDelegate -

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        Current.Log.verbose("didFinishLaunching")

        UNUserNotificationCenter.current().delegate = self

        var opts: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert, .providesAppNotificationSettings]
        if #available(watchOS 13.0, *) {
            opts.insert(.announcement)
        }

        if #available(watchOSApplicationExtension 6.0, *) {
            WKExtension.shared().registerForRemoteNotifications()
        }

        UNUserNotificationCenter.current().requestAuthorization(options: opts) { (granted, error) in
            Current.Log.verbose("Requested notifications access \(granted), \(String(describing: error))")
        }

        setupWatchCommunicator()

        // schedule the next background refresh
        BackgroundRefreshScheduler.shared.schedule()
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
        // If the application was previously in the background, optionally refresh the user interface.

        Current.Log.verbose("didBecomeActive")
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state.
        // This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message)
        // or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        Current.Log.verbose("willResignActive")
        BackgroundRefreshScheduler.shared.schedule()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks.
        // Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                Current.Log.verbose("WKWatchConnectivityRefreshBackgroundTask received")
                BackgroundRefreshScheduler.shared.schedule()
                self.updateComplications()
                self.bgTask = backgroundTask
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true,
                                              estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                watchConnectivityTask = connectivityTask
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                Current.Log.verbose("Should rejoin URLSession! \(String(describing: urlIdentifier))")
                self.bgTask = urlSessionTask
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
                Current.Log.verbose("\(family.description) complication opened app")
            }
        }
    }

    // swiftlint:disable:next function_body_length
    func setupWatchCommunicator() {
        Communicator.shared.activationStateChangedObservers.add { state in
            Current.Log.verbose("Activation state changed: \(state)")

            _ = HomeAssistantAPI.SyncWatchContext()
        }

        Communicator.shared.reachabilityChangedObservers.add { reachability in
            Current.Log.verbose("Reachability changed: \(reachability)")
        }

        Communicator.shared.immediateMessageReceivedObservers.add { message in
            Current.Log.verbose("Received message: \(message.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.guaranteedMessageReceivedObservers.add { message in
            Current.Log.verbose("Received guaranteed message! \(message)")
        }

        Communicator.shared.blobReceivedObservers.add { blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.contextUpdatedObservers.add { context in
            Current.Log.verbose("Received context: \(context)")

            _ = HomeAssistantAPI.SyncWatchContext()

            let realm = Realm.live()

            if let connInfoData = context.content["connection_info"] as? Data {
                let connInfo = try? JSONDecoder().decode(ConnectionInfo.self, from: connInfoData)
                Current.settingsStore.connectionInfo = connInfo

                if let api = HomeAssistantAPI.authenticatedAPI() {
                    Current.updateWith(authenticatedAPI: api)
                } else {
                    Current.Log.error("Failed to get authed API after context sync!")
                }
            }

            if let tokenInfoData = context.content["token_info"] as? Data {
                let tokenInfo = try? JSONDecoder().decode(TokenInfo.self, from: tokenInfoData)
                Current.settingsStore.tokenInfo = tokenInfo

                if let api = HomeAssistantAPI.authenticatedAPI() {
                    Current.updateWith(authenticatedAPI: api)
                } else {
                    Current.Log.error("Failed to get authed API after context sync!")
                }
            }

            if let actionsDictionary = context.content["actions"] as? [[String: Any]] {
                let actions = actionsDictionary.compactMap { Action(JSON: $0) }

                Current.Log.verbose("Updating actions from context \(actions)")

                try? realm.write {
                    realm.delete(realm.objects(Action.self))
                    realm.add(actions, update: .all)
                }
            }

            if let complicationsDictionary = context.content["complications"] as? [[String: Any]] {
                let complications = complicationsDictionary.compactMap { WatchComplication(JSON: $0) }

                Current.Log.verbose("Updating complications from context \(complications)")

                try? realm.write {
                    realm.delete(realm.objects(WatchComplication.self))
                    realm.add(complications, update: .all)
                }

                self.updateComplications()

                CLKComplicationServer.sharedInstance().activeComplications?.forEach {
                    CLKComplicationServer.sharedInstance().reloadTimeline(for: $0)
                }
            }

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.complicationInfoReceivedObservers.add { complicationInfo in
            Current.Log.verbose("Received complication info: \(complicationInfo)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }
    }

    private func endWatchConnectivityBackgroundTaskIfNecessary() {
        // First check we're not expecting more data
        guard !Communicator.shared.hasPendingDataToBeReceived else { return }
        // And then end the task (if there is one!)
        self.watchConnectivityTask?.setTaskCompleted()
    }

    func updateComplications() {
        let urlID = NSUUID().uuidString

        self.urlIdentifier = urlID

        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: urlID)
        backgroundConfigObject.sessionSendsLaunchEvents = true

        guard let api = HomeAssistantAPI.authenticatedAPI(urlConfig: backgroundConfigObject) else {
            Current.Log.error("Couldn't get HAAPI instance")
            return
        }

        _ = api.updateComplications().ensure {
            self.bgTask?.setTaskCompleted()
        }.catch { error in
            Current.Log.error("Error updating complications! \(error)")
        }
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Current.Log.verbose("Successfully registered for push notifications! APNS token: \(apnsToken)")
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        Current.Log.error("Error when trying to register for push: \(error)")
    }
}

extension ExtensionDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                // swiftlint:disable:next line_length
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
}
