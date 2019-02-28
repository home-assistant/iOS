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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
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
            let realm = Realm.live()

            if message.identifier == "actions" {
                let content = message.content

                if let actionJSONs = content["data"]! as? [[String: Any]] {
                    // swiftlint:disable:next force_try
                    try! realm.write {
                        for actionJSON in actionJSONs {
                            if let action = Action(JSON: actionJSON) {
                                Current.Log.verbose("ACTION \(action)")
                                realm.add(action, update: true)
                            }
                        }
                    }
                }
            }
        }

        Communicator.shared.blobReceivedObservers.add { blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.contextUpdatedObservers.add { context in
            Current.Log.verbose("Received context: \(context)")

            if let connInfoStr = context.content["connection_info"] as? String {
                let connInfo = try? JSONDecoder().decode(ConnectionInfo.self, from: connInfoStr.data(using: .utf8)!)
                Current.settingsStore.connectionInfo = connInfo

                if let api = HomeAssistantAPI.authenticatedAPI() {
                    Current.updateWith(authenticatedAPI: api)
                } else {
                    Current.Log.error("Failed to get authed API after context sync!")
                }
            }

            if let tokenInfoStr = context.content["token_info"] as? String {
                let tokenInfo = try? JSONDecoder().decode(TokenInfo.self, from: tokenInfoStr.data(using: .utf8)!)
                Current.settingsStore.tokenInfo = tokenInfo

                if let api = HomeAssistantAPI.authenticatedAPI() {
                    Current.updateWith(authenticatedAPI: api)
                } else {
                    Current.Log.error("Failed to get authed API after context sync!")
                }
            }

            if let apiPassword = context.content["apiPassword"] as? String {
                Constants.Keychain["apiPassword"] = apiPassword
            }

            if let webhookID = context.content["webhook_id"] as? String {
                Current.settingsStore.webhookID = webhookID
            }

            if let webhookSecret = context.content["webhook_secret"] as? String {
                Current.settingsStore.webhookSecret = webhookSecret
            }

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.complicationInfoReceivedObservers.add { complicationInfo in
            Current.Log.verbose("Received complication info: \(complicationInfo)")

            _ = HomeAssistantAPI.SyncWatchContext()

            let realm = Realm.live()

            for (family, data) in complicationInfo.content {
                Current.Log.verbose("Family \(family)")
                Current.Log.verbose("Data \(data)")

                if let dataDict = data as? [String: Any], let complicationConfig = WatchComplication(JSON: dataDict) {
                    // swiftlint:disable:next force_try
                    try! realm.write {
                        Current.Log.verbose("Writing \(complicationConfig.Family)")
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

    var activeFamilies: [String] {
        guard let activeComplications = CLKComplicationServer.sharedInstance().activeComplications else { return [] }
        return activeComplications.map { ComplicationGroupMember(family: $0.family).rawValue }
    }

    func buildRenderTemplatePayload() -> [String: Any] {
        var json: [String: Any] = [:]

        var templates = [String: [String: String]]()

        let realm = Realm.live()

        let complications = realm.objects(WatchComplication.self)

        // Current.Log.verbose("complications", complications)

        // Current.Log.verbose("activeComplications", self.activeComplications)

        for complication in complications {
            if self.activeFamilies.contains(complication.Family.rawValue) {
                // Current.Log.verbose("ACTIVE COMPLICATION!", complication, complication.Data)
                if let textAreas = complication.Data["textAreas"] as? [String: [String: Any]] {
                    for (key, textArea) in textAreas {
                        // Current.Log.verbose("Got textArea", key, textArea)
                        if let needsRender = textArea["textNeedsRender"] as? Bool, needsRender {
                            // Current.Log.verbose("TEXT NEEDS RENDER!", key)
                            if templates[complication.Template.rawValue] == nil {
                                templates[complication.Template.rawValue] = [String: String]()
                            }
                            templates[complication.Template.rawValue]![key] = textArea["text"] as? String
                        }
                    }
                }
            }
        }

        json["templates"] = templates

        Current.Log.verbose("JSON payload to send \(json)")

        return json
    }

    func updateComplications() {

        guard let wID = Current.settingsStore.webhookID, let connInfo = Current.settingsStore.connectionInfo else {
            // swiftlint:disable:next line_length
            Current.Log.warning("Didn't find webhook URL in context \(Communicator.shared.mostRecentlyReceievedContext)")
            return
        }

        let downloadURL = connInfo.activeAPIURL.appendingPathComponent("webhook/\(wID)")

        Current.Log.verbose("Render template URL \(downloadURL)")

        let urlID = NSUUID().uuidString

        self.urlIdentifier = urlID

        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: urlID)
        backgroundConfigObject.sessionSendsLaunchEvents = true

        guard let api = HomeAssistantAPI.authenticatedAPI(urlConfig: backgroundConfigObject) else {
            fatalError("Couldn't get HAAPI instance")
        }

        _ = api.webhook("render_complications", payload: self.buildRenderTemplatePayload(),
                        callingFunctionName: "renderComplications").done { (respJSON: Any) in

            Current.Log.verbose("Got JSON \(respJSON)")
            guard let jsonDict = respJSON as? [String: [String: String]] else {
                Current.Log.error("Unable to cast JSON to [String: [String: String]]!")
                return
            }

            Current.Log.verbose("JSON Dict1 \(jsonDict)")

            var updatedComplications: [WatchComplication] = []

            for (templateName, textAreas) in jsonDict {
                let pred = NSPredicate(format: "rawTemplate == %@", templateName)
                let realm = Realm.live()
                guard let complication = realm.objects(WatchComplication.self).filter(pred).first else {
                    Current.Log.error("Couldn't get complication from DB for \(templateName)")
                    continue
                }

                guard var storedAreas = complication.Data["textAreas"] as? [String: [String: Any]] else {
                    Current.Log.error("Couldn't cast stored areas")
                    continue
                }

                for (textAreaKey, renderedText) in textAreas {
                    storedAreas[textAreaKey]!["renderedText"] = renderedText
                }

                // swiftlint:disable:next force_try
                try! realm.write {
                    complication.Data["textAreas"] = storedAreas
                }

                updatedComplications.append(complication)

                Current.Log.verbose("complication \(complication.Data)")
            }

            CLKComplicationServer.sharedInstance().activeComplications?.forEach {
                CLKComplicationServer.sharedInstance().reloadTimeline(for: $0)
            }

        }.ensure {
            self.bgTask?.setTaskCompleted()
        }.catch { err in
            Current.Log.error("Error when rendering complications: \(err)")
        }
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

extension ExtensionDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                // swiftlint:disable:next line_length
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
}
