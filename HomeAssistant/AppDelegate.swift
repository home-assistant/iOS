//
//  AppDelegate.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Alamofire
import AlamofireNetworkActivityIndicator
import CallbackURLKit
import Communicator
import Firebase
import Iconic
import Intents
import KeychainAccess
import Lokalise
import PromiseKit
import RealmSwift
import SafariServices
import Shared
import UIKit
import UserNotifications

let keychain = Constants.Keychain

let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

@UIApplicationMain
// swiftlint:disable:next type_body_length
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var safariVC: SFSafariViewController?

    private(set) var regionManager: RegionManager!

    override init() {
        super.init()
        UIFont.overrideInitialize()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        setDefaults()

        UNUserNotificationCenter.current().delegate = self

        self.setupFirebase()

        self.configureLokalise()

        let launchingForLocation = launchOptions?[.location] != nil
        let event = ClientEvent(text: "Application Starting" + (launchingForLocation ? " due to location change" : ""),
                                type: .unknown)
        Current.clientEventStore.addEvent(event)

        self.registerCallbackURLKitHandlers()

        self.regionManager = RegionManager()

        Current.syncMonitoredRegions = { self.regionManager.syncMonitoredRegions() }

        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        Iconic.registerMaterialDesignIcons()

        NetworkActivityIndicatorManager.shared.isEnabled = true

        setupWatchCommunicator()

        HomeAssistantAPI.ProvideNotificationCategoriesToSystem()

        if #available(iOS 12.0, *) { setupiOS12Features() }

        self.setupView()

        _ = HomeAssistantAPI.authenticatedAPI()?.CreateEvent(eventType: "ios.finished_launching", eventData: [:])

        return true
    }

    func setupView() {
        window = UIWindow.init(frame: UIScreen.main.bounds)
        window?.backgroundColor = UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.0)

        let webView = WebViewController()

        var navController = UINavigationController(rootViewController: webView)

        if prefs.object(forKey: "onboarding_complete_newconninfo") == nil {
            navController = StoryboardScene.Onboarding.navController.instantiate()
        }

        self.window!.rootViewController = navController
        self.window!.makeKeyAndVisible()

        if Current.appConfiguration == .FastlaneSnapshot { setupFastlaneSnapshotConfiguration() }

        if let tokenInfo = Current.settingsStore.tokenInfo, let connectionInfo = Current.settingsStore.connectionInfo {
            Current.tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: tokenInfo)
        }

        Current.authenticationControllerPresenter = { controller in
            if let presentedController = navController.topViewController?.presentedViewController {
                presentedController.present(controller, animated: true, completion: nil)
                return
            }

            navController.topViewController?.present(controller, animated: true, completion: nil)
        }

        Current.signInRequiredCallback = {
            let alert = UIAlertController(title: L10n.Alerts.AuthRequired.title,
                                          message: L10n.Alerts.AuthRequired.message, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: { _ in
                navController.popToViewController(webView, animated: true)
                webView.showSettingsViewController()
            }))

            navController.present(alert, animated: true, completion: nil)

            alert.popoverPresentationController?.sourceView = self.window?.rootViewController?.view
        }

        Current.onboardingComplete = {
            self.window!.rootViewController = UINavigationController(rootViewController: webView)
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {}

    func applicationDidEnterBackground(_ application: UIApplication) {
        _ = HomeAssistantAPI.authenticatedAPI()?.CreateEvent(eventType: "ios.entered_background", eventData: [:])
    }

    func applicationWillEnterForeground(_ application: UIApplication) {}

    func applicationDidBecomeActive(_ application: UIApplication) {
        _ = HomeAssistantAPI.authenticatedAPI()?.CreateEvent(eventType: "ios.became_active", eventData: [:])
        Lokalise.shared.checkForUpdates { (updated, error) in
            if let error = error {
                Current.Log.error("Error when updating Lokalise: \(error)")
                return
            }
            if updated {
                Current.Log.info("Lokalise updated? \(updated)")
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Swift.Error) {
        Current.Log.error("Error when trying to register for push: \(error)")
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Current.Log.verbose("Successfully registered for push notifications! APNS token: \(apnsToken)")

        var tokenType: MessagingAPNSTokenType = .prod

        if Current.appConfiguration == .Debug {
            tokenType = .sandbox
        }

        Messaging.messaging().setAPNSToken(deviceToken, type: tokenType)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Current.Log.verbose("Received remote notification in completion handler!")

        Messaging.messaging().appDidReceiveMessage(userInfo)

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            Current.Log.warning("Remote notification handler failed because api was not authenticated")
            completionHandler(.failed)
            return
        }

        if var userInfoDict = userInfo as? [String: Any],
            let hadict = userInfoDict["homeassistant"] as? [String: String], let command = hadict["command"] {
                switch command {
                case "request_location_update":
                    if prefs.bool(forKey: "locationUpdateOnNotification") == false {
                        completionHandler(.noData)
                    }
                    Current.Log.verbose("Received remote request to provide a location update")
                    api.GetAndSendLocation(trigger: .PushNotification).done { success in
                        Current.Log.verbose("Did successfully send location when requested via APNS? \(success)")
                        completionHandler(.newData)
                    }.catch { error in
                        Current.Log.error("Error when attempting to submit location update: \(error)")
                        completionHandler(.failed)
                    }
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

        var updatePromise: Promise<Void> = api.UpdateSensors(.BackgroundFetch).asVoid()

        if Current.settingsStore.locationEnabled && prefs.bool(forKey: "locationUpdateOnBackgroundFetch") {
            updatePromise = api.GetAndSendLocation(trigger: .BackgroundFetch).asVoid()
        }

        firstly {
            return when(fulfilled: [updatePromise, api.updateComplications().asVoid()])
        }.done { _ in
            completionHandler(.newData)
        }.catch { error in
            Current.Log.error("Error when attempting to update data during background fetch: \(error)")
            completionHandler(.failed)
        }
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Current.Log.verbose("Received URL: \(url)")
        var serviceData: [String: String] = [:]
        if let queryItems = url.queryItems {
            serviceData = queryItems
        }
        guard let host = url.host else { return true }
        switch host.lowercased() {
        case "x-callback-url":
            return Manager.shared.handleOpen(url: url)
        case "call_service":
            callServiceURLHandler(url, serviceData)
        case "fire_event":
            fireEventURLHandler(url, serviceData)
        case "send_location":
            sendLocationURLHandler()
        case "auth-callback": // homeassistant://auth-callback
           NotificationCenter.default.post(name: Notification.Name("AuthCallback"), object: nil,
                                           userInfo: ["url": url])
        default:
            Current.Log.warning("Can't route incoming URL: \(url)")
            showAlert(title: L10n.errorLabel, message: L10n.UrlHandler.NoService.message(url.host!))
        }
        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completionHandler(false)
            return
        }

        let name = shortcutItem.localizedTitle
        let actionPromise = api.HandleAction(actionID: shortcutItem.type, actionName: name,
                                             source: .AppShortcut)

        var promises = [actionPromise]

        if shortcutItem.type == "sendLocation" {
            promises.append(api.GetAndSendLocation(trigger: .AppShortcut))
        }

        when(fulfilled: promises).done { worked in
            completionHandler(worked[0])
        }.catch { error in
            Current.Log.error("Received error from handleAction during App Shortcut: \(error)")
            completionHandler(false)
        }
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL,
            let actualURLStr = url.queryItems?["url"], let actualURL = URL(string: actualURLStr) else {
            return false
        }

        return self.application(application, open: actualURL)
    }

    // MARK: - Private helpers

    // swiftlint:disable:next function_body_length
    private func registerCallbackURLKitHandlers() {
        Manager.shared.callbackURLScheme = Manager.urlSchemes?.first

        Manager.shared["fire_event"] = { parameters, success, failure, cancel in
            guard let eventName = parameters["eventName"] else {
                failure(XCallbackError.eventNameMissing)
                return
            }

            var cleanParamters = parameters
            cleanParamters.removeValue(forKey: "eventName")
            let eventData = cleanParamters

            _ = firstly {
                HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }.done { _ in
                success(nil)
            }.catch { error -> Void in
                Current.Log.error("Received error from createEvent during X-Callback-URL call: \(error)")
                failure(XCallbackError.generalError)
            }
        }

        Manager.shared["call_service"] = { parameters, success, failure, cancel in
            guard let service = parameters["service"] else {
                failure(XCallbackError.serviceMissing)
                return
            }

            let splitService = service.components(separatedBy: ".")
            let serviceDomain = splitService[0]
            let serviceName = splitService[1]

            var cleanParamters = parameters
            cleanParamters.removeValue(forKey: "service")
            let serviceData = cleanParamters

            _ = firstly {
                HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.CallService(domain: serviceDomain, service: serviceName, serviceData: serviceData)
            }.done { _ in
                success(nil)
            }.catch { error in
                Current.Log.error("Received error from callService during X-Callback-URL call: \(error)")
                failure(XCallbackError.generalError)
            }
        }

        Manager.shared["send_location"] = { parameters, success, failure, cancel in
            _ = firstly {
                HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.GetAndSendLocation(trigger: .XCallbackURL)
            }.done { _ in
                success(nil)
            }.catch { error in
                Current.Log.error("Received error from getAndSendLocation during X-Callback-URL call: \(error)")
                failure(XCallbackError.generalError)
            }
        }

        Manager.shared["render_template"] = { parameters, success, failure, cancel in
            guard let template = parameters["template"] else {
                failure(XCallbackError.templateMissing)
                return
            }

            var cleanParamters = parameters
            cleanParamters.removeValue(forKey: "template")
            let variablesDict = cleanParamters

            _ = firstly {
                HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.RenderTemplate(templateStr: template, variables: variablesDict)
            }.done { rendered in
                success(["rendered": rendered])
            }.catch { error in
                Current.Log.error("Received error from RenderTemplate during X-Callback-URL call: \(error)")
                failure(XCallbackError.generalError)
            }
        }
    }

    private func fireEventURLHandler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity

        if #available(iOS 12.0, *) {
            let interaction = INInteraction(intent: FireEventIntent(eventName: url.pathComponents[1],
                                                                    payload: url.query), response: nil)

            interaction.donate { (error) in
                if error != nil {
                    if let error = error as NSError? {
                        Current.Log.error("FireEvent Interaction donation failed: \(error)")
                    } else {
                        Current.Log.verbose("FireEvent Successfully donated interaction")
                    }
                }
            }
        }

        _ = firstly {
            HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.CreateEvent(eventType: url.pathComponents[1], eventData: serviceData)
            }.done { _ in
                showAlert(title: L10n.UrlHandler.FireEvent.Success.title,
                          message: L10n.UrlHandler.FireEvent.Success.message(url.pathComponents[1]))
            }.catch { error -> Void in
                showAlert(title: L10n.errorLabel,
                          message: L10n.UrlHandler.FireEvent.Error.message(url.pathComponents[1],
                                                                           error.localizedDescription))
        }
    }

    private func callServiceURLHandler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
        let domain = url.pathComponents[1].components(separatedBy: ".")[0]
        let service = url.pathComponents[1].components(separatedBy: ".")[1]

        if #available(iOS 12.0, *) {
            let intent = CallServiceIntent(domain: domain, service: service, payload: url.query)

            let interaction = INInteraction(intent: intent, response: nil)

            interaction.donate { (error) in
                if error != nil {
                    if let error = error as NSError? {
                        Current.Log.error("CallService Interaction donation failed: \(error)")
                    } else {
                        Current.Log.verbose("CallService Successfully donated interaction")
                    }
                }
            }
        }

        _ = firstly {
            HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.CallService(domain: domain, service: service, serviceData: serviceData)
            }.done { _ in
                showAlert(title: L10n.UrlHandler.CallService.Success.title,
                          message: L10n.UrlHandler.CallService.Success.message(url.pathComponents[1]))
            }.catch { error in
                showAlert(title: L10n.errorLabel,
                          message: L10n.UrlHandler.CallService.Error.message(url.pathComponents[1],
                                                                             error.localizedDescription))
        }
    }

    private func sendLocationURLHandler() {
        // homeassistant://send_location/
        _ = firstly {
            HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.GetAndSendLocation(trigger: .URLScheme)
            }.done { _ in
                showAlert(title: L10n.UrlHandler.SendLocation.Success.title,
                          message: L10n.UrlHandler.SendLocation.Success.message)
            }.catch { error in
                showAlert(title: L10n.errorLabel,
                          message: L10n.UrlHandler.SendLocation.Error.message(error.localizedDescription))
        }
    }

    func setupWatchCommunicator() {
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

                guard let actionName = message.content["ActionName"] as? String else {
                    Current.Log.warning("actionName either does not exist or is not a string in the payload")
                    message.replyHandler?(["fired": false])
                    return
                }

                guard let actionID = message.content["ActionID"] as? String else {
                    Current.Log.warning("ActionID either does not exist or is not a string in the payload")
                    message.replyHandler?(["fired": false])
                    return
                }

                HomeAssistantAPI.authenticatedAPIPromise.then { api in
                    api.HandleAction(actionID: actionID, actionName: actionName, source: .Watch)
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
                Current.setUserProperty?(modelIdentifier, "PairedAppleWatch")
            }
        }
    }

    @available(iOS 12.0, *)
    func suggestSiriShortcuts() {
        let generics: [INIntent] = [FireEventIntent(), SendLocationIntent(), CallServiceIntent(),
                                    GetCameraImageIntent(), RenderTemplateIntent()]
        var shortcutsToSuggest: [INShortcut] = generics.compactMap { INShortcut(intent: $0) }

        _ = HomeAssistantAPI.authenticatedAPIPromise.then { api in
            api.GetEvents()
            }.then { eventsResp -> Promise<HomeAssistantAPI> in
                for event in eventsResp {
                    if let eventName = event.Event {
                        if eventName == "*" {
                            continue
                        }
                        if let shortcut = INShortcut(intent: FireEventIntent(eventName: eventName)) {
                            shortcutsToSuggest.append(shortcut)
                        }
                    }
                }

                return HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.GetServices()
            }.done { serviceResp in
                for domainContainer in serviceResp {
                    let domain = domainContainer.Domain
                    for service in domainContainer.Services {
                        let desc = service.value.Description
                        if let shortcut = INShortcut(intent: CallServiceIntent(domain: domain, service: service.key,
                                                                               description: desc)) {
                            shortcutsToSuggest.append(shortcut)
                        }
                    }
                }

                Current.Log.verbose("Suggesting \(shortcutsToSuggest.count) shortcuts to Siri")

                INVoiceShortcutCenter.shared.setShortcutSuggestions(shortcutsToSuggest)
        }
    }

    @available(iOS 12.0, *)
    func setupiOS12Features() {
        // Tell the system we have a app notification settings screen and want critical alerts
        // This is effectively a migration

        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            guard settings.authorizationStatus == .authorized else {return}
            let opts: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert,
                                                .providesAppNotificationSettings]
            UNUserNotificationCenter.current().requestAuthorization(options: opts) { (granted, error) in
                Current.Log.verbose("Requested critical alert access \(granted), \(String(describing: error))")
            }
        }

        suggestSiriShortcuts()
    }

    func setupFastlaneSnapshotConfiguration() {
        // FIXME: Adapt to oAuth
//        let baseURL = URL(string: "https://privatedemo.home-assistant.io")!
//
//        keychain["apiPassword"] = "demoprivate"
//
//        let connectionInfo = ConnectionInfo(baseURL: baseURL, internalBaseURL: nil, internalSSID: nil,
//                                            basicAuthCredentials: nil)
//
//        let api = HomeAssistantAPI(connectionInfo: connectionInfo,
//                                   authenticationMethod: .legacy(apiPassword: "demoprivate"))
//        Current.updateWith(authenticatedAPI: api)
//        Current.settingsStore.connectionInfo = connectionInfo
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

    func configureLokalise() {
        Lokalise.shared.setProjectID("834452985a05254348aee2.46389241",
                                     token: "fe314d5c54f3000871ac18ccac8b62b20c143321")
        Lokalise.shared.swizzleMainBundle()

        Lokalise.shared.localizationType = Current.appConfiguration.lokaliseEnv
    }

    func setupFirebase() {
        var fileName = "GoogleService-Info-Development"

        if Current.appConfiguration == .Beta {
            fileName = "GoogleService-Info-Beta"
        } else if Current.appConfiguration == .Release {
            fileName = "GoogleService-Info-Release"
        }

        guard let filePath = Bundle.main.path(forResource: fileName, ofType: "plist") else {
            fatalError("Couldn't get file named \(fileName) from bundle")
        }

        Current.Log.verbose("Setting up Firebase with plist at path: \(filePath)")

        guard let fileopts = FirebaseOptions(contentsOfFile: filePath) else {
            fatalError("Couldn't load environment specific Firebase config file")
        }
        FirebaseApp.configure(options: fileopts)

        Messaging.messaging().delegate = self

        if Current.settingsStore.notificationsEnabled {
            Current.Log.verbose("Calling UIApplication.shared.registerForRemoteNotifications()")
            UIApplication.shared.registerForRemoteNotifications()
        }

        Current.loadCrashlytics()

        Messaging.messaging().isAutoInitEnabled = prefs.bool(forKey: "messagingEnabled")
        Analytics.setAnalyticsCollectionEnabled(prefs.bool(forKey: "analyticsEnabled"))

        Current.logEvent = { (eventName: String, params: [String: Any]?) -> Void in
            Current.Log.verbose("Logging event \(eventName) to analytics")
            Analytics.logEvent(eventName, parameters: params)
        }

        Current.setUserProperty = { (value: String?, name: String) -> Void in
            Current.Log.verbose("Setting user property \(name) to \(value)")
            Analytics.setUserProperty(value, forName: name)
        }
    }
}

extension AppConfiguration {
    var lokaliseEnv: LokaliseLocalizationType {
        if prefs.bool(forKey: "showTranslationKeys") {
            return .debug
        }
        switch self {
        case .Release:
            return .release
        case .Beta:
            return .prerelease
        case .Debug, .FastlaneSnapshot:
            return .local
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
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

        if let openUrl = userInfo["url"] as? String,
            let url = URL(string: openUrl) {
            if prefs.bool(forKey: "confirmBeforeOpeningUrl") {
                let alert = UIAlertController(title: L10n.Alerts.OpenUrlFromNotification.title,
                                              message: L10n.Alerts.OpenUrlFromNotification.message(openUrl),
                                              preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: L10n.noLabel, style: UIAlertAction.Style.default, handler: nil))
                alert.addAction(UIAlertAction(title: L10n.yesLabel, style: UIAlertAction.Style.default, handler: { _ in
                    UIApplication.shared.open(url,
                                              options: [:],
                                              completionHandler: nil)
                }))
                var rootViewController = UIApplication.shared.keyWindow?.rootViewController
                if let navigationController = rootViewController as? UINavigationController {
                    rootViewController = navigationController.viewControllers.first
                }
                rootViewController?.present(alert, animated: true, completion: nil)
                alert.popoverPresentationController?.sourceView = rootViewController?.view
            } else {
                UIApplication.shared.open(url, options: [:],
                                          completionHandler: nil)
            }
        }
        firstly {
            HomeAssistantAPI.authenticatedAPIPromise
        }.then { api in
            api.handlePushAction(identifier: response.actionIdentifier, userInfo: userInfo,
                                 userInput: userText)
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
        var rootViewController = self.window?.rootViewController
        if let navigationController = rootViewController as? UINavigationController {
            rootViewController = navigationController.viewControllers.first
        }
        rootViewController?.dismiss(animated: false, completion: {
            let navController = UINavigationController(rootViewController: view)
            rootViewController?.present(navController, animated: true, completion: nil)
        })
        let navController = UINavigationController(rootViewController: view)
        rootViewController?.present(navController, animated: true, completion: nil)
    }
}

enum XCallbackError: FailureCallbackError {
    case generalError
    case eventNameMissing
    case serviceMissing
    case templateMissing

    var code: Int {
        switch self {
        case .generalError:
            return 0
        case .eventNameMissing:
            return 1
        case .serviceMissing:
            return 2
        case .templateMissing:
            return 2
        }
    }

    var message: String {
        switch self {
        case .generalError:
            return L10n.UrlHandler.XCallbackUrl.Error.general
        case .eventNameMissing:
            return L10n.UrlHandler.XCallbackUrl.Error.eventNameMissing
        case .serviceMissing:
            return L10n.UrlHandler.XCallbackUrl.Error.serviceMissing
        case .templateMissing:
            return L10n.UrlHandler.XCallbackUrl.Error.templateMissing
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        Current.Log.info("Firebase registration token refreshed, new token: \(fcmToken)")

        Current.settingsStore.pushID = fcmToken

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            Current.Log.warning("Could not get authenticated API")
            return
        }

        _ = api.UpdateRegistration()
    }
    // swiftlint:disable:next file_length
}
