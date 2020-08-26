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
#if !targetEnvironment(macCatalyst)
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
import Sentry
import MBProgressHUD
#if DEBUG
import SimulatorStatusMagic
#endif

let keychain = Constants.Keychain

let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

@UIApplicationMain
// swiftlint:disable:next type_body_length
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var windowController: WindowController?
    var safariVC: SFSafariViewController?

    private let windowControllerPromise: Guarantee<WindowController>
    private let windowControllerSeal: (WindowController) -> Void

    private func webViewControllerPromise() -> Guarantee<WebViewController> {
        windowControllerPromise.then { $0.webViewControllerPromise }
    }

    private var zoneManager: ZoneManager?

    private var periodicUpdateTimer: Timer? {
        willSet {
            if periodicUpdateTimer != newValue {
                periodicUpdateTimer?.invalidate()
            }
        }
    }

    override init() {
        (self.windowControllerPromise, self.windowControllerSeal) = Guarantee<WindowController>.pending()

        super.init()
    }

    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if NSClassFromString("XCTest") != nil {
            return true
        }

        setDefaults()
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

        self.setupSentry()
        self.setupFirebase()
        self.setupModels()

        self.configureLokalise()

        let launchingForLocation = launchOptions?[.location] != nil
        let event = ClientEvent(text: "Application Starting" + (launchingForLocation ? " due to location change" : ""),
                                type: .unknown)
        Current.clientEventStore.addEvent(event)

        self.registerCallbackURLKitHandlers()

        self.zoneManager = ZoneManager()

        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        Iconic.registerMaterialDesignIcons()

        setupWatchCommunicator()

        if #available(iOS 12.0, *) { setupiOS12Features() }

        // window must be created before willFinishLaunching completes, or state restoration will not occur
        setupWindow()

        return true
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if NSClassFromString("XCTest") != nil {
            return true
        }

        setupTokens()

        windowController?.setup()

        _ = HomeAssistantAPI.authenticatedAPI()?.CreateEvent(eventType: "ios.finished_launching", eventData: [:])
        connectAPI(reason: .cold)

        setup14Workaround()
        checkForUpdate()

        return true
    }

    static let hasAsked14Workaround = "has asked about ios 14 workaround"
    static let hasAgreed14Workaround = "has agreed to ios 14 workaround"

    private func setup14Workaround() {
        guard !prefs.bool(forKey: Self.hasAsked14Workaround) else {
            return
        }

        if #available(iOS 14, *), Current.isTestFlight || Current.appConfiguration == .Debug {
            let controller = UIAlertController(
                title: "Work around iOS 14 background crash?",
                message: "This may at some point corrupt the app's settings, requiring you delete the app to continue.",
                preferredStyle: .alert
            )
            controller.addAction(UIAlertAction(title: "Enable Workaround", style: .destructive, handler: { _ in
                prefs.set(true, forKey: Self.hasAgreed14Workaround)
                prefs.set(true, forKey: Self.hasAsked14Workaround)
            }))
            controller.addAction(UIAlertAction(title: "Do Not Work Around", style: .default, handler: { _ in
                prefs.set(false, forKey: Self.hasAgreed14Workaround)
                prefs.set(true, forKey: Self.hasAsked14Workaround)
            }))
            controller.addAction(UIAlertAction(title: "Ask Again Later", style: .cancel, handler: nil))
            window?.rootViewController?.present(controller, animated: true, completion: nil)
        }
    }

    func setupWindow() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.tintColor = Constants.tintColor
        window.restorationIdentifier = StateRestorationKey.mainWindow.rawValue
        window.makeKeyAndVisible()
        self.window = window

        let windowController = WindowController(window: window)
        self.windowController = windowController
        windowControllerSeal(windowController)
    }

    func setupTokens() {
        if Current.appConfiguration == .FastlaneSnapshot { setupFastlaneSnapshotConfiguration() }

        if let tokenInfo = Current.settingsStore.tokenInfo, let connectionInfo = Current.settingsStore.connectionInfo {
            Current.tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: tokenInfo)
        }
    }

    @available(iOS 13, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        if builder.system == .main {
            MenuManager(builder: builder).update()
        }
    }

    @objc internal func openAbout() {
        // TODO: multiple scenes, open window
        let controller = AboutViewController()
        let navigationController = UINavigationController(rootViewController: controller)
        window?.rootViewController?.present(navigationController, animated: true, completion: nil)
    }

    @objc internal func openMenuUrl(_ command: AnyObject) {
        guard #available(iOS 13, *), let command = command as? UICommand else {
            return
        }

        if let url = MenuManager.url(from: command) {
            _ = application(UIApplication.shared, open: url, options: [:])
        }
    }

    @objc internal func openPreferences() {
        // TODO: multiple scenes, open window
        webViewControllerPromise().done {
            $0.showSettingsViewController()
        }
    }

    @objc internal func openHelp() {
        openURLInBrowser(
            URL(string: "https://companion.home-assistant.io")!,
            nil
        )
    }

    func applicationWillResignActive(_ application: UIApplication) {}

    func applicationDidEnterBackground(_ application: UIApplication) {
        _ = HomeAssistantAPI.authenticatedAPI()?.CreateEvent(eventType: "ios.entered_background", eventData: [:])
        invalidatePeriodicUpdateTimer()

        if prefs.bool(forKey: Self.hasAgreed14Workaround) {
            Current.Log.error("*** deleting realm lock file, remember this workaround? ***")
            let lockURL = Current.realm().configuration.fileURL!.appendingPathExtension("lock")
            try? FileManager.default.removeItem(at: lockURL)
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        connectAPI(reason: .warm)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        _ = HomeAssistantAPI.authenticatedAPI()?.CreateEvent(eventType: "ios.became_active", eventData: [:])

        #if !targetEnvironment(macCatalyst)
        Lokalise.shared.checkForUpdates { (updated, error) in
            if let error = error {
                Current.Log.error("Error when updating Lokalise: \(error)")
                return
            }
            if updated {
                Current.Log.info("Lokalise updated? \(updated)")
            }
        }
        #endif
    }

    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        if windowController?.requiresOnboarding == true {
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

    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        if Current.settingsStore.restoreLastURL == false {
            // if we let it capture state -- even if we don't use the url -- it will take a screenshot
            Current.Log.info("disallowing state to be saved due to setting")
            return false
        }

        Current.Log.info("allowing state to be saved")
        return true
    }

    func application(
        _ application: UIApplication,
        viewControllerWithRestorationIdentifierPath identifierComponents: [String],
        coder: NSCoder
    ) -> UIViewController? {
        return windowController?.viewController(withRestorationIdentifierPath: identifierComponents)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Current.Log.error("Error when trying to register for push: \(error)")
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Current.Log.verbose("Successfully registered for push notifications! APNS token: \(apnsToken)")
        Current.setUserProperty?(apnsToken, "APNS Token")

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

                    application.backgroundTask(withName: "push-location-request") { remaining in
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

        application.backgroundTask(withName: "background-fetch") { remaining in
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

            return when(fulfilled: [updatePromise, api.updateComplications().asVoid()]).asVoid()
        }.done {
            completionHandler(.newData)
        }.catch { error in
            Current.Log.error("Error when attempting to update data during background fetch: \(error)")
            completionHandler(.failed)
        }
    }

    func application(_ app: UIApplication,
                     open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
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
        case "perform_action":
            performActionURLHandler(url, serviceData: serviceData)
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

        application.backgroundTask(withName: "shortcut-item") { remaining -> Promise<Void> in
            if shortcutItem.type == "sendLocation" {
                return api.GetAndSendLocation(trigger: .AppShortcut, maximumBackgroundTime: remaining)
            } else {
                return api.HandleAction(actionID: shortcutItem.type, source: .AppShortcut)
            }
        }.done {
            completionHandler(true)
        }.catch { error in
            Current.Log.error("Received error from handleAction during App Shortcut: \(error)")
            completionHandler(false)
        }
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        Current.Log.info(userActivity)

        switch Current.tags.handle(userActivity: userActivity) {
        case .handled(let type):
            let (icon, text) = { () -> (MaterialDesignIcons, String) in
                 switch type {
                 case .nfc:
                     return (.nfcVariantIcon, L10n.Nfc.tagRead)
                 case .generic:
                     return (.qrcodeIcon, L10n.Nfc.genericTagRead)
                 }
             }()
            showFullScreenConfirm(icon: icon, text: text)
            return true
        case .unhandled:
            return false
        case .open(let url):
            // NFC-based URL
            return self.application(application, open: url)
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

    private func invalidatePeriodicUpdateTimer() {
        periodicUpdateTimer = nil
    }

    private func schedulePeriodicUpdateTimer() {
        guard periodicUpdateTimer == nil || periodicUpdateTimer?.isValid == false else {
            return
        }

        guard UIApplication.shared.applicationState != .background else {
            // it's fine to schedule, but we don't wanna fire two when we come back to foreground later
            Current.Log.info("not scheduling periodic update; backgrounded")
            return
        }

        guard let interval = Current.settingsStore.periodicUpdateInterval else {
            Current.Log.info("not scheduling periodic update; disabled")
            return
        }

        periodicUpdateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.connectAPI(reason: .periodic)
        }
    }

    private func connectAPI(reason: HomeAssistantAPI.ConnectReason) {
        firstly {
            HomeAssistantAPI.authenticatedAPIPromise
        }.then { api in
            return UIApplication.shared.backgroundTask(withName: "connect-api") { _ in
                api.Connect(reason: reason)
            }
        }.done {
            Current.Log.info("Connect finished for reason \(reason)")
        }.catch { error in
            // if the error is e.g. token is invalid, we'll force onboarding through status-code-watching mechanisms
            Current.Log.error("Couldn't connect for reason \(reason): \(error)")
        }.finally {
            self.schedulePeriodicUpdateTimer()
        }
    }

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

    private func performActionURLHandler(_ url: URL, serviceData: [String: String]) {
        let pathComponents = url.pathComponents
        guard pathComponents.count > 1 else {
            Current.Log.error("not enough path components for perform action handler")
            return
        }

        let source: HomeAssistantAPI.ActionSource = {
            if let sourceString = serviceData["source"],
               let source = HomeAssistantAPI.ActionSource(rawValue: sourceString) {
                return source
            } else {
                return .URLHandler
            }
        }()

        let actionID = url.pathComponents[1]

        guard let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID) else {
            showFullScreenConfirm(icon: .alertCircleIcon, text: L10n.UrlHandler.Error.actionNotFound)
            return
        }

        showFullScreenConfirm(icon: MaterialDesignIcons(named: action.IconName), text: action.Text)

        HomeAssistantAPI.authenticatedAPI()?
            .HandleAction(actionID: actionID, source: source)
            .cauterize()
    }

    func checkForUpdate() {
        guard #available(macCatalyst 13, *) else {
            // don't need to look for updates on iOS
            return
        }

        Current.updater.check().done { [window] update in
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
            window?.rootViewController?.present(alert, animated: true, completion: nil)
        }.catch { error in
            Current.Log.error("no update available: \(error)")
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
                Current.setUserProperty?(modelIdentifier, "PairedAppleWatch")
            }
        }
    }

    @available(iOS 12.0, *)
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

        let api = HomeAssistantAPI(connectionInfo: connectionInfo, tokenInfo: tokenInfo)

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

    func configureLokalise() {
        #if !targetEnvironment(macCatalyst)
        Lokalise.shared.setProjectID("834452985a05254348aee2.46389241",
                                     token: "fe314d5c54f3000871ac18ccac8b62b20c143321")
        Lokalise.shared.swizzleMainBundle()

        Lokalise.shared.localizationType = Current.appConfiguration.lokaliseEnv
        #endif
    }

    func setupSentry() {
        Current.Log.add(destination: SentryLogDestination())

        SentrySDK.start { options in
            options.dsn = "https://762c198b86594fa2b6bedf87028db34d@o427061.ingest.sentry.io/5372775"
            options.debug = NSNumber(value: Current.appConfiguration == .Debug)
            options.enableAutoSessionTracking = NSNumber(value: Current.settingsStore.privacy.analytics)
            options.enabled = NSNumber(value: Current.settingsStore.privacy.crashes)
            options.maxBreadcrumbs = 1000

            var integrations = type(of: options).defaultIntegrations()

            let analyticsIntegrations = Set([
                NSStringFromClass(SentryAutoBreadcrumbTrackingIntegration.self),
                NSStringFromClass(SentryAutoSessionTrackingIntegration.self)
            ])

            let crashesIntegrations = Set([
                NSStringFromClass(SentryCrashIntegration.self)
            ])

            if !Current.settingsStore.privacy.crashes {
                integrations.removeAll(where: { crashesIntegrations.contains($0) })
            }

            if !Current.settingsStore.privacy.analytics {
                integrations.removeAll(where: { analyticsIntegrations.contains($0) })
            }

            Current.Log.info("enabled integrations: \(integrations)")
            options.integrations = integrations
        }

        Current.logError = { error in
            // crash reporting is controlled by the crashes key, but this is more like analytics
            guard Current.settingsStore.privacy.analytics else { return}

            Current.Log.error("error: \(error.debugDescription)")
            SentrySDK.capture(error: error)
        }

        Current.logEvent = { (eventName: String, params: [String: Any]) -> Void in
            guard Current.settingsStore.privacy.analytics else { return}

            Current.Log.verbose("event \(eventName): \(params)")
            SentrySDK.capture(message: eventName) { scope in
                scope.setTags(params.mapValues { String(describing: $0)})
            }
        }

        Current.setUserProperty = { (value: String?, name: String) -> Void in
            SentrySDK.configureScope { scope in
                scope.setEnvironment(Current.appConfiguration.description)

                if let value = value {
                    Current.Log.verbose("setting tag \(name) to '\(value)'")
                    scope.setTag(value: value, key: name)
                } else {
                    Current.Log.verbose("removing tag \(name)")
                    scope.removeTag(key: name)
                }
            }
        }
    }

    func setupFirebase() {
        #if targetEnvironment(simulator)
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

#if !targetEnvironment(macCatalyst)
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
#endif

extension AppDelegate: UNUserNotificationCenterDelegate {
    private func open(urlString openUrlRaw: String) {
        if let webviewURL = Current.settingsStore.connectionInfo?.webviewURL(from: openUrlRaw) {
            webViewControllerPromise().done { webViewController in
                webViewController.open(inline: webviewURL)
            }
        } else if let url = URL(string: openUrlRaw) {
            let presentingViewController = { () -> UIViewController? in
                var rootViewController = self.window!.rootViewController
                while let controller = rootViewController?.presentedViewController {
                    rootViewController = controller
                }
                return rootViewController
            }

            let triggerOpen = {
                openURLInBrowser(url, presentingViewController())
            }

            if prefs.bool(forKey: "confirmBeforeOpeningUrl"), let presenter = presentingViewController() {
                let alert = UIAlertController(title: L10n.Alerts.OpenUrlFromNotification.title,
                                              message: L10n.Alerts.OpenUrlFromNotification.message(openUrlRaw),
                                              preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(
                    title: L10n.noLabel,
                    style: UIAlertAction.Style.default,
                    handler: nil
                ))
                alert.addAction(UIAlertAction(
                    title: L10n.yesLabel,
                    style: UIAlertAction.Style.default
                ) { _ in
                    triggerOpen()
                })

                alert.popoverPresentationController?.sourceView = presenter.view
                presenter.present(alert, animated: true, completion: nil)
            } else {
                triggerOpen()
            }
        }
    }

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
            open(urlString: openURLRaw)
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
                open(urlString: url)
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
            UIApplication.shared.backgroundTask(withName: "handle-push-action") { _ in
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
        var rootViewController = self.window?.rootViewController
        if let navigationController = rootViewController as? UINavigationController {
            rootViewController = navigationController.viewControllers.first
        }
        rootViewController?.dismiss(animated: false, completion: {
            let navController = UINavigationController(rootViewController: view)
            rootViewController?.present(navController, animated: true, completion: nil)
        })
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

        if let existingToken = Current.settingsStore.pushID, existingToken != fcmToken {
            Current.Log.warning("FCM token has changed from \(existingToken) to \(fcmToken)")
        }

        Current.setUserProperty?(fcmToken, "FCM Token")
        Current.settingsStore.pushID = fcmToken

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            Current.Log.warning("Could not get authenticated API")
            return
        }

        _ = api.UpdateRegistration()
    }
    // swiftlint:disable:next file_length
}
