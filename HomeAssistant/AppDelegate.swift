//
//  AppDelegate.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import PromiseKit
import UserNotifications
import AlamofireNetworkActivityIndicator
import KeychainAccess
import Alamofire
import RealmSwift
import Shared
import SafariServices
import Intents
import Communicator
import Iconic
import arek

let keychain = Constants.Keychain

let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

@UIApplicationMain
// swiftlint:disable:next type_body_length
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var safariVC: SFSafariViewController?

    private(set) var regionManager: RegionManager!
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let launchingForLocation = launchOptions?[.location] != nil
        let launchMessage = "Application Starting" + (launchingForLocation ? " due to location change" : "")
        let event = ClientEvent(text: launchMessage, type: .unknown)
        Current.clientEventStore.addEvent(event)

        self.regionManager = RegionManager()

        Current.syncMonitoredRegions = { self.regionManager.syncMonitoredRegions() }

        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        Iconic.registerMaterialDesignIcons()

        NetworkActivityIndicatorManager.shared.isEnabled = true

        UNUserNotificationCenter.current().delegate = self

        setDefaults()

        setupWatchCommunicator()

        if #available(iOS 12.0, *) { setupiOS12Features() }

        window = UIWindow.init(frame: UIScreen.main.bounds)
        window?.backgroundColor = UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.0)

        let webView = WebViewController()

        let navController = UINavigationController(rootViewController: webView)
        navController.setToolbarHidden(false, animated: false)
        navController.setNavigationBarHidden(true, animated: false)

        self.window!.rootViewController = navController
        self.window!.makeKeyAndVisible()

        if Current.appConfiguration == .FastlaneSnapshot { setupFastlaneSnapshotConfiguration() }

        if let tokenInfo = Current.settingsStore.tokenInfo,
            let connectionInfo = Current.settingsStore.connectionInfo {
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
                                          message: L10n.Alerts.AuthRequired.message,
                                          preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                          handler: { _ in
                                            navController.popToViewController(webView, animated: true)
                                            webView.showSettingsViewController()
            }))

            navController.present(alert, animated: true, completion: nil)
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {}

    func applicationDidEnterBackground(_ application: UIApplication) {}

    func applicationWillEnterForeground(_ application: UIApplication) {}

    func applicationDidBecomeActive(_ application: UIApplication) { CheckPermissionsStatus() }

    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return
        }

        let tokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})

        prefs.setValue(tokenString, forKey: "deviceToken")

        print("Registering push with tokenString: \(tokenString)")

        _ = api.registerDeviceForPush(deviceToken: tokenString).done { resp in
            if let pushId = resp.PushId {
                print("Registered for push. Platform: \(resp.SNSPlatform ?? "MISSING"), PushID: \(pushId)")
                prefs.setValue(pushId, forKey: "pushID")
                Current.settingsStore.pushID = pushId
                _ = api.identifyDevice()
            }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Swift.Error) {
        print("Error when trying to register for push", error)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Received remote notification in completion handler!")
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            print("Remote notification handler failed because api was not authenticated")
            completionHandler(.failed)
            return
        }

        if let userInfoDict = userInfo as? [String: Any],
            let hadict = userInfoDict["homeassistant"] as? [String: String], let command = hadict["command"] {
                    switch command {
                    case "request_location_update":
                        if prefs.bool(forKey: "locationUpdateOnNotification") == false {
                            completionHandler(.noData)
                        }
                        print("Received remote request to provide a location update")
                        api.getAndSendLocation(trigger: .PushNotification).done { success in
                            print("Did successfully send location when requested via APNS?", success)
                            completionHandler(.newData)
                        }.catch { error in
                            print("Error when attempting to submit location update", error.localizedDescription)
                            completionHandler(.failed)
                        }
                    default:
                        print("Received unknown command via APNS!", userInfo)
                        completionHandler(.noData)
                    }
        } else {
            completionHandler(.failed)
        }
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            print("Background fetch failed because api was not authenticated")
            completionHandler(.failed)
            return
        }

        if prefs.bool(forKey: "locationUpdateOnBackgroundFetch") == false {
            completionHandler(UIBackgroundFetchResult.noData)
            return
        }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .full)
        print("Background fetch activated at \(timestamp)!")
        if Current.settingsStore.locationEnabled && prefs.bool(forKey: "locationUpdateOnBackgroundFetch") {
            api.getAndSendLocation(trigger: .BackgroundFetch).done { _ in
                print("Sending location via background fetch")
                completionHandler(UIBackgroundFetchResult.newData)
                }.catch { error in
                    print("Error when attempting to submit location update during background fetch",
                          error.localizedDescription)
                    completionHandler(UIBackgroundFetchResult.failed)
            }
        } else {
            api.identifyDevice().done { _ in
                completionHandler(UIBackgroundFetchResult.newData)
            }.catch { error in
                print("Error when attempting to identify device during background fetch", error.localizedDescription)
                completionHandler(UIBackgroundFetchResult.failed)
            }
        }
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        var serviceData: [String: String] = [:]
        if let queryItems = url.queryItems {
            serviceData = queryItems
        }
        guard let host = url.host else { return true }
        switch host {
        case "call_service":
            callServiceURLHAndler(url, serviceData)
        case "fire_event":
            fireEventURLHandler(url, serviceData)
        case "send_location":
            sendLocationURLHandler()
        case "auth-callback": // homeassistant://auth-callback
           NotificationCenter.default.post(name: Notification.Name("AuthCallback"), object: nil,
                                           userInfo: ["url": url])
        default:
            print("Can't route", url.host!)
            showAlert(title: L10n.errorLabel,
                      message: L10n.UrlHandler.NoService.message(url.host!))
        }
        return true
    }

    // MARK: - Private helpers

    private func fireEventURLHandler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity

        if #available(iOS 12.0, *) {
            let interaction = INInteraction(intent: FireEventIntent(eventName: url.pathComponents[1],
                                                                    payload: url.query), response: nil)

            interaction.donate { (error) in
                if error != nil {
                    if let error = error as NSError? {
                        print("FireEvent Interaction donation failed: \(error)")
                    } else {
                        print("FireEvent Successfully donated interaction")
                    }
                }
            }
        }

        _ = firstly {
            HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.createEvent(eventType: url.pathComponents[1], eventData: serviceData)
            }.done { _ in
                showAlert(title: L10n.UrlHandler.FireEvent.Success.title,
                          message: L10n.UrlHandler.FireEvent.Success.message(url.pathComponents[1]))
            }.catch { error -> Void in
                showAlert(title: L10n.errorLabel,
                          message: L10n.UrlHandler.FireEvent.Error.message(url.pathComponents[1],
                                                                           error.localizedDescription))
        }
    }

    private func callServiceURLHAndler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
        let domain = url.pathComponents[1].components(separatedBy: ".")[0]
        let service = url.pathComponents[1].components(separatedBy: ".")[1]

        if #available(iOS 12.0, *) {
            let intent = CallServiceIntent(domain: domain, service: service, payload: url.query)

            let interaction = INInteraction(intent: intent, response: nil)

            interaction.donate { (error) in
                if error != nil {
                    if let error = error as NSError? {
                        print("CallService Interaction donation failed: \(error)")
                    } else {
                        print("CallService Successfully donated interaction")
                    }
                }
            }
        }

        _ = firstly {
            HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.callService(domain: domain, service: service, serviceData: serviceData)
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
                api.getAndSendLocation(trigger: .URLScheme)
            }.done { _ in
                showAlert(title: L10n.UrlHandler.SendLocation.Success.title,
                          message: L10n.UrlHandler.SendLocation.Success.message)
            }.catch { error in
                showAlert(title: L10n.errorLabel,
                          message: L10n.UrlHandler.SendLocation.Error.message(error.localizedDescription))
        }
    }

    func updateWatchContext() {
        if let wID = Current.settingsStore.webhookID, let url = Current.settingsStore.connectionInfo?.activeAPIURL {
            var content: JSONDictionary = Communicator.shared.mostRecentlyReceievedContext.content

            // content["webhook_id"] = wID
            // content["url"] = url
            content["webhook_url"] = url.appendingPathComponent("webhook/\(wID)").absoluteString

            let context = Context(content: content)

            do {
                try Communicator.shared.sync(context: context)
            } catch let error as NSError {
                print("Updating the context failed: ", error.localizedDescription)
            }

            print("Set the context to", context)
        }
    }

    func setupWatchCommunicator() {
        Communicator.shared.activationStateChangedObservers.add { state in
            print("Activation state changed: ", state)
            self.updateWatchContext()
        }

        Communicator.shared.watchStateUpdatedObservers.add { watchState in
            print("Watch state changed: ", watchState)
            self.updateWatchContext()
        }

        Communicator.shared.reachabilityChangedObservers.add { reachability in
            print("Reachability changed: ", reachability)
        }

        Communicator.shared.immediateMessageReceivedObservers.add { message in
            print("Received message: ", message.identifier)

            if message.identifier == "ActionRowPressed" {
                print("Received ActionRowPressed", message, message.content)

                guard let actionName = message.content["ActionName"] as? String else {
                    print("actionName either does not exist or is not a string in the payload")
                    message.replyHandler?(["fired": false])
                    return
                }

                guard let actionID = message.content["ActionID"] as? String else {
                    print("ActionID either does not exist or is not a string in the payload")
                    message.replyHandler?(["fired": false])
                    return
                }

                HomeAssistantAPI.authenticatedAPIPromise.then { api in
                    api.handleAction(actionID: actionID, actionName: actionName, source: .Watch)
                }.done { _ in
                    message.replyHandler?(["fired": true])
                }.catch { err -> Void in
                    print("Error during action event fire: \(err)")
                    message.replyHandler?(["fired": false])
                }
            }
        }

        Communicator.shared.blobReceivedObservers.add { blob in
            print("Received blob: ", blob.identifier)
        }

        Communicator.shared.contextUpdatedObservers.add { context in
            print("Received context: ", context)
        }
    }

    @available(iOS 12.0, *)
    func suggestSiriShortcuts() {
        var shortcutsToSuggest: [INShortcut] = []

        if let shortcut = INShortcut(intent: FireEventIntent()) {
            shortcutsToSuggest.append(shortcut)
        }

        if let shortcut = INShortcut(intent: SendLocationIntent()) {
            shortcutsToSuggest.append(shortcut)
        }

        if let shortcut = INShortcut(intent: CallServiceIntent()) {
            shortcutsToSuggest.append(shortcut)
        }

        if let shortcut = INShortcut(intent: GetCameraImageIntent()) {
            shortcutsToSuggest.append(shortcut)
        }

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

                print("Suggesting", shortcutsToSuggest.count, "shortcuts to Siri")

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
                print("Requested critical alert access", granted, error.debugDescription)
            }
        }

        suggestSiriShortcuts()
    }

    func setupFastlaneSnapshotConfiguration() {
        let baseURL = URL(string: "https://privatedemo.home-assistant.io")!

        keychain["apiPassword"] = "demoprivate"

        let connectionInfo = ConnectionInfo(baseURL: baseURL, internalBaseURL: nil, internalSSID: nil,
                                            basicAuthCredentials: nil)

        let api = HomeAssistantAPI(connectionInfo: connectionInfo,
                                   authenticationMethod: .legacy(apiPassword: "demoprivate"))
        Current.updateWith(authenticatedAPI: api)
        Current.settingsStore.connectionInfo = connectionInfo
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
                if let tabBarController = rootViewController as? UITabBarController {
                    rootViewController = tabBarController.selectedViewController
                }
                rootViewController?.present(alert, animated: true, completion: nil)
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
            print("Error: \(err)")
        }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       // swiftlint:disable:next line_length
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
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
        let view = SettingsDetailViewController()
        view.detailGroup = "notifications"
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
// swiftlint:disable:next file_length
}
