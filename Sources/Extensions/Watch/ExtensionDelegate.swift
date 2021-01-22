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
    // MARK: Fileprivate

    fileprivate var watchConnectivityBackgroundPromise: Guarantee<Void>
    fileprivate var watchConnectivityBackgroundSeal: (()) -> Void

    override init() {
        (watchConnectivityBackgroundPromise, watchConnectivityBackgroundSeal) = Guarantee<Void>.pending()
        super.init()
    }

    // MARK: - WKExtensionDelegate -

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        Current.Log.verbose("didFinishLaunching")

        UNUserNotificationCenter.current().delegate = self

        var opts: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert, .providesAppNotificationSettings]
        if #available(watchOS 6.0, *) {
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
        Current.backgroundRefreshScheduler.schedule().cauterize()
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
        Current.backgroundRefreshScheduler.schedule().cauterize()
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

                firstly {
                    updateComplications()
                }.then {
                    Current.backgroundRefreshScheduler.schedule()
                }.done {
                    backgroundTask.setTaskCompletedWithSnapshot(false)
                }
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true,
                                              estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                enqueueForCompletion(connectivityTask)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                Current.webhooks.handleBackground(for: urlSessionTask.sessionIdentifier) {
                    Current.backgroundRefreshScheduler.schedule().done {
                        urlSessionTask.setTaskCompletedWithSnapshot(false)
                    }
                }
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
        let complication: WatchComplication?

        if #available(watchOS 7, *),
           let identifier = userInfo?[CLKLaunchedComplicationIdentifierKey] as? String,
           identifier != CLKDefaultComplicationIdentifier {
            complication = Current.realm().object(ofType: WatchComplication.self, forPrimaryKey: identifier)
        } else if let date = userInfo?[CLKLaunchedTimelineEntryDateKey] as? Date,
                  let clkFamily = date.complicationFamilyFromEncodedDate {
            let family = ComplicationGroupMember(family: clkFamily)
            complication = Current.realm().object(ofType: WatchComplication.self, forPrimaryKey: family.rawValue)
        } else {
            complication = nil
        }

        if let complication = complication {
            Current.Log.info("launched for \(complication.identifier) of family \(complication.Family)")
        } else {
            Current.Log.verbose("unknown or no complication launched the app")
        }
    }

    // swiftlint:disable:next function_body_length
    func setupWatchCommunicator() {
        Communicator.State.observe { state in
            Current.Log.verbose("Activation state changed: \(state)")

            _ = HomeAssistantAPI.SyncWatchContext()
        }

        Reachability.observe { reachability in
            Current.Log.verbose("Reachability changed: \(reachability)")
        }

        InteractiveImmediateMessage.observe { message in
            Current.Log.verbose("Received message: \(message.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        ImmediateMessage.observe { message in
            Current.Log.verbose("Received message: \(message.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        GuaranteedMessage.observe { message in
            Current.Log.verbose("Received guaranteed message! \(message)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Blob.observe { blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Context.observe { context in
            Current.Log.verbose("Received context: \(context)")

            _ = HomeAssistantAPI.SyncWatchContext()

            let realm = Current.realm()

            if let connInfoData = context.content["connection_info"] as? Data {
                let connInfo = try? JSONDecoder().decode(ConnectionInfo.self, from: connInfoData)
                Current.settingsStore.connectionInfo = connInfo
            }

            if let tokenInfoData = context.content["token_info"] as? Data {
                let tokenInfo = try? JSONDecoder().decode(TokenInfo.self, from: tokenInfoData)
                Current.settingsStore.tokenInfo = tokenInfo
                Current.resetAPI()
            }

            if let actionsDictionary = context.content["actions"] as? [[String: Any]] {
                let actions = actionsDictionary.compactMap { try? Action(JSON: $0) }

                Current.Log.verbose("Updating actions from context \(actions)")

                try? realm.write {
                    realm.delete(realm.objects(Action.self))
                    realm.add(actions, update: .all)
                }
            }

            if let complicationsDictionary = context.content["complications"] as? [[String: Any]] {
                let complications = complicationsDictionary.compactMap { try? WatchComplication(JSON: $0) }

                Current.Log.verbose("Updating complications from context \(complications)")

                try? realm.write {
                    realm.delete(realm.objects(WatchComplication.self))
                    realm.add(complications, update: .all)
                }
            }

            self.updateComplications().done {
                self.endWatchConnectivityBackgroundTaskIfNecessary()
            }
        }

        ComplicationInfo.observe { complicationInfo in
            Current.Log.verbose("Received complication info: \(complicationInfo)")

            self.updateComplications().done {
                self.endWatchConnectivityBackgroundTaskIfNecessary()
            }
        }
    }

    private func enqueueForCompletion(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        DispatchQueue.main.async { [self] in
            if Communicator.shared.hasPendingDataToBeReceived {
                // wait for it to send the next set of data
                watchConnectivityBackgroundPromise.done {
                    task.setTaskCompletedWithSnapshot(false)
                }
            } else {
                // nothing else to be received
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    private func endWatchConnectivityBackgroundTaskIfNecessary() {
        DispatchQueue.main.async { [self] in
            guard !Communicator.shared.hasPendingDataToBeReceived else { return }

            // complete the current one
            watchConnectivityBackgroundSeal(())
            // and set up a new one for the next chain of updates
            (watchConnectivityBackgroundPromise, watchConnectivityBackgroundSeal) = Guarantee<Void>.pending()
        }
    }

    func updateComplications() -> Guarantee<Void> {
        Current.api.then {
            $0.updateComplications(passively: true)
        }.recover { _ in
            ()
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
