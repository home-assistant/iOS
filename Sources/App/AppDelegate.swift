//
//  AppDelegate.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Alamofire
import CallbackURLKit
import Communicator
import Firebase
import KeychainAccess
#if canImport(Lokalise) && !targetEnvironment(macCatalyst)
import Lokalise
#endif
import PromiseKit
import RealmSwift
import SafariServices
import Shared
import XCGLogger
import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseCore
import MBProgressHUD
#if DEBUG
import SimulatorStatusMagic
#endif

let keychain = Constants.Keychain

let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

private extension UIApplication {
    var typedDelegate: AppDelegate {
        // swiftlint:disable:next force_cast
        delegate as! AppDelegate
    }
}

extension Environment {
    var sceneManager: SceneManager {
        UIApplication.shared.typedDelegate.sceneManager
    }
}

@UIApplicationMain
// swiftlint:disable:next type_body_length
class AppDelegate: UIResponder, UIApplicationDelegate {
    @available(iOS, deprecated: 13.0)
    var window: UIWindow? {
        get {
            return sceneManager.compatibility.windowController?.window
        }
        set { // swiftlint:disable:this unused_setter_value
            fatalError("window is not settable in app delegate")
        }
    }

    let sceneManager = SceneManager()
    let lifecycleManager = LifecycleManager()

    private var zoneManager: ZoneManager?

    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        setDefaults()

        Current.backgroundTask = ApplicationBackgroundTaskRunner()

        Current.isBackgroundRequestsImmediate = {
            if Current.isCatalyst {
                return false
            } else {
                return application.applicationState != .background
            }
        }

        #if targetEnvironment(simulator)
        Current.tags = SimulatorTagManager()
        #else
        Current.tags = iOSTagManager()
        #endif

        UNUserNotificationCenter.current().delegate = self

        self.setupFirebase()
        self.setupModels()
        self.setupLocalization()

        let launchingForLocation = launchOptions?[.location] != nil
        let event = ClientEvent(text: "Application Starting" + (launchingForLocation ? " due to location change" : ""),
                                type: .unknown)
        Current.clientEventStore.addEvent(event)

        self.zoneManager = ZoneManager()

        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        Iconic.registerMaterialDesignIcons()

        setupWatchCommunicator()
        setupiOS12Features()

        if #available(iOS 13, *) {

        } else {
            // window must be created before willFinishLaunching completes, or state restoration will not occur
            sceneManager.compatibility.willFinishLaunching()
        }

        return true
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if NSClassFromString("XCTest") != nil {
            return true
        }

        setupTokens()

        if #available(iOS 13, *) {

        } else {
            sceneManager.compatibility.didFinishLaunching()
        }

        lifecycleManager.didFinishLaunching()

        checkForUpdate()

        return true
    }

    func setupTokens() {
        if Current.appConfiguration == .FastlaneSnapshot { setupFastlaneSnapshotConfiguration() }

        if let tokenInfo = Current.settingsStore.tokenInfo {
            Current.tokenManager = TokenManager(tokenInfo: tokenInfo)
        }
    }

    @available(iOS 13, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        if builder.system == .main {
            MenuManager(builder: builder).update()
        }
    }

    @available(iOS 13, *)
    @objc internal func openAbout() {
        precondition(Current.sceneManager.supportsMultipleScenes)
        sceneManager.activateAnyScene(for: .about)
    }

    @available(iOS 13, *)
    @objc internal func openMenuUrl(_ command: AnyObject) {
        guard let command = command as? UICommand, let url = MenuManager.url(from: command) else {
            return
        }

        let delegate: Guarantee<WebViewSceneDelegate> = sceneManager.scene(for: .init(activity: .webView))
        delegate.done {
            $0.urlHandler?.handle(url: url)
        }
    }

    @available(iOS 13, *)
    @objc internal func openPreferences() {
        precondition(Current.sceneManager.supportsMultipleScenes)
        sceneManager.activateAnyScene(for: .settings)
    }

    @available(iOS 13, *)
    @objc internal func openActionsPreferences(_ command: UICommand) {
        precondition(Current.sceneManager.supportsMultipleScenes)
        let delegate: Guarantee<SettingsSceneDelegate> = sceneManager.scene(for: .init(activity: .settings))
        delegate.done { $0.pushDetail(group: "actions", animated: true) }
    }

    @objc internal func openHelp() {
        openURLInBrowser(
            URL(string: "https://companion.home-assistant.io")!,
            nil
        )
    }

    @available(iOS 13, *)
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let activity = options.userActivities
            .compactMap { SceneActivity(activityIdentifier: $0.activityType) }
            .first ?? .webView
        return activity.configuration
    }

    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        if #available(iOS 13, *) {
            return false
        } else {
            if sceneManager.compatibility.windowController?.requiresOnboarding == true {
                Current.Log.info("disallowing state to be restored due to onboarding")
                return false
            }

            if Current.appConfiguration == .FastlaneSnapshot {
                Current.Log.info("disallowing state to be restored due to fastlane snapshot")
                return false
            }

            if NSClassFromString("XCTest") != nil {
                return false
            }

            Current.Log.info("allowing state to be restored")
            return true
        }
    }

    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        if #available(iOS 13, *) {
            return false
        } else {
            if Current.settingsStore.restoreLastURL == false {
                // if we let it capture state -- even if we don't use the url -- it will take a screenshot
                Current.Log.info("disallowing state to be saved due to setting")
                return false
            }

            Current.Log.info("allowing state to be saved")
            return true
        }
    }

    func application(
        _ application: UIApplication,
        viewControllerWithRestorationIdentifierPath identifierComponents: [String],
        coder: NSCoder
    ) -> UIViewController? {
        if #available(iOS 13, *) {
            return nil
        } else {
            return sceneManager.compatibility.windowController?.viewController(
                withRestorationIdentifierPath: identifierComponents
            )
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Current.Log.error("Error when trying to register for push: \(error)")
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Current.Log.verbose("Successfully registered for push notifications! APNS token: \(apnsToken)")
        Current.crashReporter.setUserProperty(value: apnsToken, name: "APNS Token")

        var tokenType: MessagingAPNSTokenType = .prod

        if Current.appConfiguration == .Debug {
            tokenType = .sandbox
        }

        Messaging.messaging().setAPNSToken(deviceToken, type: tokenType)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Current.Log.verbose("Received remote notification in completion handler!")

        Messaging.messaging().appDidReceiveMessage(userInfo)

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            Current.Log.warning("Remote notification handler failed because api was not authenticated")
            completionHandler(.failed)
            return
        }

        if let userInfoDict = userInfo as? [String: Any],
            let hadict = userInfoDict["homeassistant"] as? [String: String], let command = hadict["command"] {
                switch command {
                case "request_location_update":
                    if prefs.bool(forKey: "locationUpdateOnNotification") == false {
                        completionHandler(.noData)
                        return
                    }

                    Current.Log.verbose("Received remote request to provide a location update")

                    Current.backgroundTask(withName: "push-location-request") { remaining in
                        api.GetAndSendLocation(trigger: .PushNotification, maximumBackgroundTime: remaining)
                    }.done { success in
                        Current.Log.verbose("Did successfully send location when requested via APNS? \(success)")
                        completionHandler(.newData)
                    }.catch { error in
                        Current.Log.error("Error when attempting to submit location update: \(error)")
                        completionHandler(.failed)
                    }
                case "clear_badge":
                    Current.Log.verbose("Setting badge to 0 as requested")
                    UIApplication.shared.applicationIconBadgeNumber = 0
                default:
                    Current.Log.warning("Received unknown command via APNS! \(userInfo)")
                    completionHandler(.noData)
                }
        } else {
            completionHandler(.failed)
        }
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            Current.Log.warning("Background fetch failed because api was not authenticated")
            completionHandler(.failed)
            return
        }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .full)
        Current.Log.verbose("Background fetch activated at \(timestamp)!")

        Current.backgroundTask(withName: "background-fetch") { remaining in
            let updatePromise: Promise<Void>

            if Current.settingsStore.isLocationEnabled(for: UIApplication.shared.applicationState),
                prefs.bool(forKey: "locationUpdateOnBackgroundFetch") {
                updatePromise = api.GetAndSendLocation(
                    trigger: .BackgroundFetch,
                    maximumBackgroundTime: remaining
                ).asVoid()
            } else {
                updatePromise = api.UpdateSensors(trigger: .BackgroundFetch).asVoid()
            }

            return updatePromise
        }.done {
            completionHandler(.newData)
        }.catch { error in
            Current.Log.error("Error when attempting to update data during background fetch: \(error)")
            completionHandler(.failed)
        }
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if #available(iOS 13, *) {
            fatalError("scene delegate should be invoked on iOS 13")
        } else {
            return sceneManager.compatibility.urlHandler?.handle(url: url) ?? false
        }
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        if #available(iOS 13, *) {
            fatalError("scene delegate should be invoked on iOS 13")
        } else {
            enum NoHandler: Error {
                case noHandler
            }

            firstly { () -> Promise<Void> in
                if let handler = sceneManager.compatibility.urlHandler {
                    return handler.handle(shortcutItem: shortcutItem)
                } else {
                    throw NoHandler.noHandler
                }
            }.done {
                completionHandler(true)
            }.catch { _ in
                completionHandler(false)
            }
        }
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if #available(iOS 13, *) {
            fatalError("scene delegate should be invoked on iOS 13")
        } else {
            return sceneManager.compatibility.urlHandler?.handle(userActivity: userActivity) ?? false
        }
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        if WebhookManager.isManager(forSessionIdentifier: identifier) {
            Current.Log.info("starting webhook handler for \(identifier)")
            Current.webhooks.handleBackground(for: identifier, completionHandler: completionHandler)
        } else {
            Current.Log.error("couldn't find appropriate session for for \(identifier)")
            completionHandler()
        }
    }

    // MARK: - Private helpers

    @objc func checkForUpdate(_ sender: AnyObject? = nil) {
        Current.updater.check().done { [sceneManager] update in
            let alert = UIAlertController(
                title: L10n.Updater.UpdateAvailable.title,
                message: update.body,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: L10n.Updater.UpdateAvailable.open(update.name),
                style: .default,
                handler: { _ in
                    UIApplication.shared.open(update.htmlUrl, options: [:], completionHandler: nil)
                }
            ))
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: nil))

            sceneManager.webViewWindowControllerPromise.done {
                $0.present(alert, animated: true, completion: nil)
            }
        }.catch { [sceneManager] error in
            Current.Log.error("check error: \(error)")

            if sender != nil {
                // sender means it's from a ui element, so give a result
                let alert = UIAlertController(
                    title: L10n.Updater.NoUpdatesAvailable.title,
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: nil))

                sceneManager.webViewWindowControllerPromise.done {
                    $0.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    func setupWatchCommunicator() {
        _ = NotificationCenter.default.addObserver(
            forName: SettingsStore.connectionInfoDidChange,
            object: nil,
            queue: nil
        ) { _ in
            _ = HomeAssistantAPI.SyncWatchContext()
        }

        Communicator.shared.activationStateChangedObservers.add { state in
            Current.Log.verbose("Activation state changed: \(state)")
            _ = HomeAssistantAPI.SyncWatchContext()
        }

        Communicator.shared.watchStateUpdatedObservers.add { watchState in
            Current.Log.verbose("Watch state changed: \(watchState)")
            _ = HomeAssistantAPI.SyncWatchContext()
        }

        Communicator.shared.reachabilityChangedObservers.add { reachability in
            Current.Log.verbose("Reachability changed: \(reachability)")
        }

        Communicator.shared.immediateMessageReceivedObservers.add { message in
            Current.Log.verbose("Received message: \(message.identifier)")

            if message.identifier == "ActionRowPressed" {
                Current.Log.verbose("Received ActionRowPressed \(message) \(message.content)")

                guard let actionID = message.content["ActionID"] as? String else {
                    Current.Log.warning("ActionID either does not exist or is not a string in the payload")
                    message.replyHandler?(["fired": false])
                    return
                }

                HomeAssistantAPI.authenticatedAPIPromise.then { api in
                    api.HandleAction(actionID: actionID, source: .Watch)
                }.done { _ in
                    message.replyHandler?(["fired": true])
                }.catch { err -> Void in
                    Current.Log.error("Error during action event fire: \(err)")
                    message.replyHandler?(["fired": false])
                }
            }
        }

        Communicator.shared.blobReceivedObservers.add { blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")
        }

        Communicator.shared.contextUpdatedObservers.add { context in
            Current.Log.verbose("Received context: \(context.content.keys) \(context.content)")

            if let modelIdentifier = context.content["watchModel"] as? String {
                Current.crashReporter.setUserProperty(value: modelIdentifier, name: "PairedAppleWatch")
            }
        }
    }

    func setupiOS12Features() {
        // Tell the system we have a app notification settings screen and want critical alerts
        // This is effectively a migration

        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            guard settings.authorizationStatus == .authorized else {return}

            UNUserNotificationCenter.current().requestAuthorization(options: .defaultOptions) { (granted, error) in
                Current.Log.verbose("Requested critical alert access \(granted), \(String(describing: error))")
            }
        }
    }

    func setupFastlaneSnapshotConfiguration() {
        #if targetEnvironment(simulator)
        SDStatusBarManager.sharedInstance()?.enableOverrides()
        #endif

        UIView.setAnimationsEnabled(false)

        guard let urlStr = prefs.string(forKey: "url"), let url = URL(string: urlStr) else {
            fatalError("Required fastlane argument 'url' not provided or invalid!")
        }

        guard let token = prefs.string(forKey: "token") else {
            fatalError("Required fastlane argument 'token' not provided or invalid!")
        }

        guard let webhookID = prefs.string(forKey: "webhookID") else {
            fatalError("Required fastlane argument 'webhookID' not provided or invalid!")
        }

        let connectionInfo = ConnectionInfo(externalURL: url, internalURL: nil, cloudhookURL: nil, remoteUIURL: nil,
                                            webhookID: webhookID,
                                            webhookSecret: prefs.string(forKey: "webhookSecret"),
                                            internalSSIDs: nil)

        let tokenInfo = TokenInfo(accessToken: token, refreshToken: "", expiration: Date.distantFuture)

        let api = HomeAssistantAPI(tokenInfo: tokenInfo)

        Current.settingsStore.tokenInfo = tokenInfo
        Current.settingsStore.connectionInfo = connectionInfo
        Current.updateWith(authenticatedAPI: api)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            Current.Log.verbose("Requested notifications \(granted), \(String(describing: error))")
        }
    }

    // swiftlint:disable:next function_body_length
    func handleShortcutNotification(_ shortcutName: String, _ shortcutDict: [String: String]) {
        var inputParams: CallbackURLKit.Parameters = shortcutDict
        inputParams["name"] = shortcutName

        Current.Log.verbose("Sending params in shortcut \(inputParams)")

        let eventName: String = "ios.shortcut_run"
        let deviceDict: [String: String] = [
            "sourceDevicePermanentID": Constants.PermanentID, "sourceDeviceName": UIDevice.current.name,
            "sourceDeviceID": Current.settingsStore.deviceID
        ]
        var eventData: [String: Any] = ["name": shortcutName, "input": shortcutDict, "device": deviceDict]

        var successHandler: CallbackURLKit.SuccessCallback?

        if shortcutDict["ignore_result"] == nil {
            successHandler = { (params) in
                Current.Log.verbose("Received params from shortcut run \(String(describing: params))")
                eventData["status"] = "success"
                eventData["result"] = params?["result"]

                Current.Log.verbose("Success, sending data \(eventData)")

                _ = firstly {
                    HomeAssistantAPI.authenticatedAPIPromise
                    }.then { api in
                        api.CreateEvent(eventType: eventName, eventData: eventData)
                    }.catch { error -> Void in
                        Current.Log.error("Received error from createEvent during shortcut run \(error)")
                }
            }
        }

        let failureHandler: CallbackURLKit.FailureCallback = { (error) in
            eventData["status"] = "failure"
            eventData["error"] = error.XCUErrorParameters

            _ = firstly {
                HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }.catch { error -> Void in
                Current.Log.error("Received error from createEvent during shortcut run \(error)")
            }
        }

        let cancelHandler: CallbackURLKit.CancelCallback = {
            eventData["status"] = "cancelled"

            _ = firstly {
                HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }.catch { error -> Void in
                Current.Log.error("Received error from createEvent during shortcut run \(error)")
            }
        }

        do {
            try Manager.shared.perform(action: "run-shortcut", urlScheme: "shortcuts",
                                       parameters: inputParams, onSuccess: successHandler,
                                       onFailure: failureHandler, onCancel: cancelHandler)
        } catch let error as NSError {
            Current.Log.error("Running shortcut failed \(error)")

            eventData["status"] = "error"
            eventData["error"] = error.localizedDescription

            _ = firstly {
                HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }.catch { error -> Void in
                Current.Log.error("Received error from CallbackURLKit perform \(error)")
            }
        }
    }

    func setupLocalization() {
        #if canImport(Lokalise) && !targetEnvironment(macCatalyst)
        let lokalise = with(Lokalise.shared) {
            $0.setProjectID(
                "834452985a05254348aee2.46389241",
                token: "fe314d5c54f3000871ac18ccac8b62b20c143321"
            )
            $0.localizationType = {
                switch Current.appConfiguration {
                case .Release:
                    if Current.isTestFlight {
                        return .prerelease
                    } else {
                        return .release
                    }
                case .Beta:
                    return .prerelease
                case .Debug, .FastlaneSnapshot:
                    return .local
                }
            }()
            // applies to e.g. storyboards and whatnot, but not L10n-read strings
            $0.swizzleMainBundle()
        }

        Current.localized.add(stringProvider: { request in
            let string = lokalise.localizedString(forKey: request.key, value: nil, table: request.table)
            if string != request.key {
                return string
            } else {
                return nil
            }
        })
        #endif

        Current.localized.add(stringProvider: { request in
            if prefs.bool(forKey: "showTranslationKeys") {
                return request.key
            } else {
                return nil
            }
        })
    }

    func setupFirebase() {
        #if targetEnvironment(simulator) || DEBUG
        if FirebaseOptions.defaultOptions() == nil {
            Current.Log.error("*** Firebase options unavailable ***")
        } else {
            FirebaseApp.configure()
        }
        #else
            FirebaseApp.configure()
        #endif

        Messaging.messaging().delegate = self

        Current.Log.verbose("Calling UIApplication.shared.registerForRemoteNotifications()")
        UIApplication.shared.registerForRemoteNotifications()

        Messaging.messaging().isAutoInitEnabled = Current.settingsStore.privacy.messaging
    }

    func setupModels() {
        // Force Realm migration to happen now
        _ = Realm.live()

        Current.modelManager.cleanup().cauterize()
        Action.setupObserver()
        NotificationCategory.setupObserver()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // swiftlint:disable:next function_body_length
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        if Current.appConfiguration == .FastlaneSnapshot &&
            response.actionIdentifier == UNNotificationDismissActionIdentifier &&
            response.notification.request.content.categoryIdentifier == "map" {
            SettingsViewController.showCameraContentExtension()
        }
        Messaging.messaging().appDidReceiveMessage(response.notification.request.content.userInfo)

        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else {
            Current.Log.info("ignoring dismiss action for notification")
            completionHandler()
            return
        }

        var userText: String?
        if let textInput = response as? UNTextInputNotificationResponse {
            userText = textInput.userText
        }
        let userInfo = response.notification.request.content.userInfo

        Current.Log.verbose("User info in incoming notification \(userInfo)")

        if let shortcutDict = userInfo["shortcut"] as? [String: String],
            let shortcutName = shortcutDict["name"] {

            self.handleShortcutNotification(shortcutName, shortcutDict)

        }

        if let openURLRaw = userInfo["url"] as? String {
            sceneManager.webViewWindowControllerPromise.done { $0.open(urlString: openURLRaw) }
        } else if let openURLDictionary = userInfo["url"] as? [String: String] {
            let url = openURLDictionary.compactMap { key, value -> String? in
                if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
                    key.lowercased() == NotificationCategory.FallbackActionIdentifier {
                    return value
                } else if key.lowercased() == response.actionIdentifier.lowercased() {
                    return value
                } else {
                    return nil
                }
            }.first

            if let url = url {
                sceneManager.webViewWindowControllerPromise.done { $0.open(urlString: url) }
            } else {
                Current.Log.error(
                    "couldn't make openable url out of \(openURLDictionary) for \(response.actionIdentifier)"
                )
            }
        } else if let someUrl = userInfo["url"] {
            Current.Log.error(
                "couldn't make openable url out of \(type(of: someUrl)): \(String(describing: someUrl))"
            )
        }

        firstly {
            HomeAssistantAPI.authenticatedAPIPromise
        }.then { api in
            Current.backgroundTask(withName: "handle-push-action") { _ in
                api.handlePushAction(
                    identifier: response.actionIdentifier,
                    category: response.notification.request.content.categoryIdentifier,
                    userInfo: userInfo,
                    userInput: userText
                )
            }
        }.ensure {
            completionHandler()
        }.catch { err -> Void in
            Current.Log.error("Error when handling push action: \(err)")
        }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       // swiftlint:disable:next line_length
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)

        if notification.request.content.userInfo[XCGLogger.notifyUserInfoKey] != nil,
            UIApplication.shared.applicationState != .background {
            completionHandler([])
            return
        }

        var methods: UNNotificationPresentationOptions = [.alert, .badge, .sound]
        if let presentationOptions = notification.request.content.userInfo["presentation_options"] as? [String] {
            methods = []
            if presentationOptions.contains("sound") || notification.request.content.sound != nil {
                methods.insert(.sound)
            }
            if presentationOptions.contains("badge") {
                methods.insert(.badge)
            }
            if presentationOptions.contains("alert") {
                methods.insert(.alert)
            }
        }
        return completionHandler(methods)
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       openSettingsFor notification: UNNotification?) {
        let view = NotificationSettingsViewController()
        view.doneButton = true

        sceneManager.webViewWindowControllerPromise.done {
            var rootViewController = $0.window.rootViewController
            if let navigationController = rootViewController as? UINavigationController {
                rootViewController = navigationController.viewControllers.first
            }
            rootViewController?.dismiss(animated: false, completion: {
                let navController = UINavigationController(rootViewController: view)
                rootViewController?.present(navController, animated: true, completion: nil)
            })
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let loggableCurrent = Current.settingsStore.pushID ?? "(null)"
        let loggableNew = fcmToken ?? "(null)"

        Current.Log.info("Firebase registration token refreshed, new token: \(loggableNew)")

        if loggableCurrent != loggableNew {
            Current.Log.warning("FCM token has changed from \(loggableCurrent) to \(loggableNew)")
        }

        Current.crashReporter.setUserProperty(value: fcmToken, name: "FCM Token")
        Current.settingsStore.pushID = fcmToken

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            Current.Log.warning("Could not get authenticated API")
            return
        }

        _ = api.UpdateRegistration()
    }
    // swiftlint:disable:next file_length
}
