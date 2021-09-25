import Alamofire
import CallbackURLKit
import Communicator
import FirebaseMessaging
import KeychainAccess
#if canImport(Lokalise) && !targetEnvironment(macCatalyst)
import Lokalise
#endif
import FirebaseCore
import MBProgressHUD
import ObjectMapper
import PromiseKit
import RealmSwift
import SafariServices
import Shared
import UIKit
import XCGLogger
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

    var notificationManager: NotificationManager {
        UIApplication.shared.typedDelegate.notificationManager
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    @available(iOS, deprecated: 13.0)
    var window: UIWindow? {
        get {
            sceneManager.compatibility.windowController?.window
        }
        set { // swiftlint:disable:this unused_setter_value
            fatalError("window is not settable in app delegate")
        }
    }

    let sceneManager = SceneManager()
    let lifecycleManager = LifecycleManager()
    let notificationManager = NotificationManager()

    private var zoneManager: ZoneManager?
    private var titleSubscription: MenuManagerTitleSubscription? {
        didSet {
            if oldValue != titleSubscription {
                oldValue?.cancel()
            }
        }
    }

    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !Current.isRunningTests else {
            return true
        }

        setDefaults()

        Current.backgroundTask = ApplicationBackgroundTaskRunner()

        Current.isBackgroundRequestsImmediate = { [lifecycleManager] in
            if Current.isCatalyst {
                return false
            } else {
                return lifecycleManager.isActive
            }
        }

        Current.isForegroundApp = { [lifecycleManager] in
            lifecycleManager.isActive
        }

        #if targetEnvironment(simulator)
        Current.tags = SimulatorTagManager()
        #else
        Current.tags = iOSTagManager()
        #endif

        notificationManager.setupNotifications()
        setupFirebase()
        setupModels()
        setupLocalization()
        setupMenus()

        let launchingForLocation = launchOptions?[.location] != nil
        let event = ClientEvent(
            text: "Application Starting" + (launchingForLocation ? " due to location change" : ""),
            type: .unknown
        )
        Current.clientEventStore.addEvent(event)

        zoneManager = ZoneManager()

        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        MaterialDesignIcons.register()

        setupWatchCommunicator()
        setupiOS12Features()

        if #available(iOS 13, *) {
        } else {
            // window must be created before willFinishLaunching completes, or state restoration will not occur
            sceneManager.compatibility.willFinishLaunching()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if NSClassFromString("XCTest") != nil {
            return true
        }

        if #available(iOS 13, *) {
        } else {
            sceneManager.compatibility.didFinishLaunching()
        }

        lifecycleManager.didFinishLaunching()

        checkForUpdate()
        checkForAlerts()

        return true
    }

    @available(iOS 13, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        if builder.system == .main {
            let manager = MenuManager(builder: builder)
            manager.update()

            #if targetEnvironment(macCatalyst)
            titleSubscription = manager.subscribeStatusItemTitle(
                existing: titleSubscription,
                update: Current.macBridge.configureStatusItem(title:)
            )
            #endif
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
    @objc internal func openActionsPreferences() {
        precondition(Current.sceneManager.supportsMultipleScenes)
        let delegate: Guarantee<SettingsSceneDelegate> = sceneManager.scene(for: .init(activity: .settings))
        delegate.done { $0.pushActions(animated: true) }
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
        notificationManager.didFailToRegisterForRemoteNotifications(error: error)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationManager.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        notificationManager.didReceiveRemoteNotification(userInfo: userInfo, fetchCompletionHandler: completionHandler)
    }

    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .full)
        Current.Log.verbose("Background fetch activated at \(timestamp)!")

        Current.backgroundTask(withName: "background-fetch") { remaining in
            Current.api.then(on: nil) { api -> Promise<Void> in
                let updatePromise: Promise<Void>

                if Current.settingsStore.isLocationEnabled(for: UIApplication.shared.applicationState),
                   Current.settingsStore.locationSources.backgroundFetch {
                    updatePromise = api.GetAndSendLocation(
                        trigger: .BackgroundFetch,
                        maximumBackgroundTime: remaining
                    ).asVoid()
                } else {
                    updatePromise = api.UpdateSensors(trigger: .BackgroundFetch).asVoid()
                }

                return updatePromise
            }
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

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
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
        guard Current.updater.isSupported else { return }

        let dueToUserInteraction = sender != nil

        Current.updater.check(dueToUserInteraction: dueToUserInteraction).done { [sceneManager] update in
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

            if dueToUserInteraction {
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

    func checkForAlerts() {
        firstly {
            Current.serverAlerter.check(dueToUserInteraction: false)
        }.done { [sceneManager] alert in
            sceneManager.webViewWindowControllerPromise.done { controller in
                controller.show(alert: alert)
            }
        }.catch { error in
            Current.Log.error("check error: \(error)")
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

        // This directly mutates the data structure for observations to avoid race conditions.

        Communicator.State.observations.store[.init(queue: .main)] = { state in
            Current.Log.verbose("Activation state changed: \(state)")
            _ = HomeAssistantAPI.SyncWatchContext()
        }

        WatchState.observations.store[.init(queue: .main)] = { watchState in
            Current.Log.verbose("Watch state changed: \(watchState)")
            _ = HomeAssistantAPI.SyncWatchContext()
        }

        Reachability.observations.store[.init(queue: .main)] = { reachability in
            Current.Log.verbose("Reachability changed: \(reachability)")
        }

        InteractiveImmediateMessage.observations.store[.init(queue: .main)] = { message in
            Current.Log.verbose("Received message: \(message.identifier)")

            // TODO: move all these to something more strongly typed

            if message.identifier == "ActionRowPressed" {
                Current.Log.verbose("Received ActionRowPressed \(message) \(message.content)")
                let responseIdentifier = "ActionRowPressedResponse"

                guard let actionID = message.content["ActionID"] as? String else {
                    Current.Log.warning("ActionID either does not exist or is not a string in the payload")
                    message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
                    return
                }

                Current.api.then(on: nil) { api in
                    api.HandleAction(actionID: actionID, source: .Watch)
                }.done { _ in
                    message.reply(.init(identifier: responseIdentifier, content: ["fired": true]))
                }.catch { err -> Void in
                    Current.Log.error("Error during action event fire: \(err)")
                    message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
                }
            } else if message.identifier == "PushAction" {
                Current.Log.verbose("Received PushAction \(message) \(message.content)")
                let responseIdentifier = "PushActionResponse"

                if let infoJSON = message.content["PushActionInfo"] as? [String: Any],
                   let info = Mapper<HomeAssistantAPI.PushActionInfo>().map(JSON: infoJSON) {
                    Current.backgroundTask(withName: "watch-push-action") { _ in
                        Current.api.then(on: nil) { api in
                            api.handlePushAction(for: info)
                        }.ensure {
                            message.reply(.init(identifier: responseIdentifier))
                        }
                    }.catch { error in
                        Current.Log.error("error handling push action: \(error)")
                    }
                }
            }
        }

        Blob.observations.store[.init(queue: .main)] = { blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")
        }

        Context.observations.store[.init(queue: .main)] = { context in
            Current.Log.verbose("Received context: \(context.content.keys) \(context.content)")

            if let modelIdentifier = context.content["watchModel"] as? String {
                Current.crashReporter.setUserProperty(value: modelIdentifier, name: "PairedAppleWatch")
            }
        }

        _ = Communicator.shared
    }

    func setupiOS12Features() {
        // Tell the system we have a app notification settings screen and want critical alerts
        // This is effectively a migration

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            UNUserNotificationCenter.current().requestAuthorization(options: .defaultOptions) { granted, error in
                Current.Log.verbose("Requested critical alert access \(granted), \(String(describing: error))")
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
        let optionsFile: String = {
            switch Current.appConfiguration {
            case .Beta: return "GoogleService-Info-Beta"
            case .Debug, .FastlaneSnapshot: return "GoogleService-Info-Debug"
            case .Release: return "GoogleService-Info-Release"
            }
        }()
        if let optionsPath = Bundle.main.path(forResource: optionsFile, ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: optionsPath) {
            FirebaseApp.configure(options: options)
        } else {
            fatalError("no firebase config found")
        }

        notificationManager.setupFirebase()
    }

    func setupModels() {
        // Force Realm migration to happen now
        _ = Realm.live()

        Current.modelManager.cleanup().cauterize()
        Current.modelManager.subscribe()
        Action.setupObserver()
        NotificationCategory.setupObserver()
    }

    func setupMenus() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuRelatedSettingDidChange(_:)),
            name: SettingsStore.menuRelatedSettingDidChange,
            object: nil
        )
    }

    @objc private func menuRelatedSettingDidChange(_ note: Notification) {
        if #available(iOS 13, *) {
            UIMenuSystem.main.setNeedsRebuild()
        }
    }

    // swiftlint:disable:next file_length
}
