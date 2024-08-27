import Alamofire
import CallbackURLKit
import Communicator
import FirebaseCore
import FirebaseMessaging
import Intents
import KeychainAccess
import MBProgressHUD
import ObjectMapper
import PromiseKit
import RealmSwift
import SafariServices
import Shared
import UIKit
import XCGLogger

let keychain = AppConstants.Keychain

let prefs = UserDefaults(suiteName: AppConstants.AppGroupID)!

private extension UIApplication {
    var typedDelegate: AppDelegate {
        // swiftlint:disable:next force_cast
        delegate as! AppDelegate
    }
}

extension AppEnvironment {
    var sceneManager: SceneManager {
        UIApplication.shared.typedDelegate.sceneManager
    }

    var notificationManager: NotificationManager {
        UIApplication.shared.typedDelegate.notificationManager
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    let sceneManager = SceneManager()
    private let lifecycleManager = LifecycleManager()
    let notificationManager = NotificationManager()
    private var zoneManager: ZoneManager?
    private var titleSubscription: MenuManagerTitleSubscription? {
        didSet {
            if oldValue != titleSubscription {
                oldValue?.cancel()
            }
        }
    }

    private var watchCommunicatorService: WatchCommunicatorService?

    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MaterialDesignIcons.register()

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
        Current.clientEventStore.addEvent(event).cauterize()

        zoneManager = ZoneManager()

        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        setupWatchCommunicator()

        return true
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if NSClassFromString("XCTest") != nil {
            return true
        }

        lifecycleManager.didFinishLaunching()

        checkForUpdate()
        checkForAlerts()

        return true
    }

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

    @objc func openAbout() {
        precondition(Current.sceneManager.supportsMultipleScenes)
        sceneManager.activateAnyScene(for: .about)
    }

    @objc func openMenuUrl(_ command: AnyObject) {
        guard let command = command as? UICommand, let url = MenuManager.url(from: command) else {
            return
        }

        let delegate: Guarantee<WebViewSceneDelegate> = sceneManager.scene(for: .init(activity: .webView))
        delegate.done {
            $0.urlHandler?.handle(url: url)
        }
    }

    @objc func openPreferences() {
        precondition(Current.sceneManager.supportsMultipleScenes)
        sceneManager.activateAnyScene(for: .settings)
    }

    @objc func openActionsPreferences() {
        precondition(Current.sceneManager.supportsMultipleScenes)
        let delegate: Guarantee<SettingsSceneDelegate> = sceneManager.scene(for: .init(activity: .settings))
        delegate.done { $0.pushActions(animated: true) }
    }

    @objc func openHelp() {
        openURLInBrowser(
            URL(string: "https://companion.home-assistant.io")!,
            nil
        )
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if #available(iOS 16.0, *), connectingSceneSession.role == UISceneSession.Role.carTemplateApplication {
            return SceneActivity.carPlay.configuration
        } else {
            let activity = options.userActivities
                .compactMap { SceneActivity(activityIdentifier: $0.activityType) }
                .first ?? .webView
            return activity.configuration
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
            let updatePromise: Promise<Void>
            if Current.settingsStore.isLocationEnabled(for: UIApplication.shared.applicationState),
               Current.settingsStore.locationSources.backgroundFetch {
                updatePromise = firstly {
                    Current.location.oneShotLocation(.BackgroundFetch, remaining)
                }.then { location in
                    when(fulfilled: Current.apis.map {
                        $0.SubmitLocation(updateType: .BackgroundFetch, location: location, zone: nil)
                    })
                }.asVoid()
            } else {
                updatePromise = when(fulfilled: Current.apis.map {
                    $0.UpdateSensors(trigger: .BackgroundFetch, location: nil)
                })
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

    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        IntentHandlerFactory.handler(for: intent)
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

    private func checkForAlerts() {
        firstly {
            Current.serverAlerter.check(dueToUserInteraction: false)
        }.done { [sceneManager] alert in
            sceneManager.webViewWindowControllerPromise.done { controller in
                controller.show(alert: alert)
            }
        }.catch { error in
            Current.Log.error("check error: \(error)")
        }

        showNotificationCategoryAlertIfNeeded()
    }

    private func showNotificationCategoryAlertIfNeeded() {
        guard Current.realm().objects(NotificationCategory.self).isEmpty == false else {
            return
        }

        let userDefaults = UserDefaults.standard
        let seenKey = "category-deprecation-3-" + Current.clientVersion().description

        guard !userDefaults.bool(forKey: seenKey) else {
            return
        }

        when(fulfilled: Current.apis.map { $0.connection.caches.user.once().promise }).done { [sceneManager] users in
            guard users.contains(where: \.isAdmin) else {
                Current.Log.info("not showing because not an admin anywhere")
                return
            }

            let alert = UIAlertController(
                title: L10n.Alerts.Deprecations.NotificationCategory.title,
                message: L10n.Alerts.Deprecations.NotificationCategory.message("iOS-2022.4"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.Nfc.List.learnMore, style: .default, handler: { _ in
                userDefaults.set(true, forKey: seenKey)
                openURLInBrowser(
                    URL(string: "https://companion.home-assistant.io/app/ios/actionable-notifications")!,
                    nil
                )
            }))
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: { _ in
                userDefaults.set(true, forKey: seenKey)
            }))
            sceneManager.webViewWindowControllerPromise.done {
                $0.present(alert)
            }
        }.catch { error in
            Current.Log.error("couldn't check for if user: \(error)")
        }
    }

    private func setupWatchCommunicator() {
        watchCommunicatorService = WatchCommunicatorService()
        watchCommunicatorService?.setup()
    }

    func setupLocalization() {
        Current.localized.add(stringProvider: { request in
            if prefs.bool(forKey: "showTranslationKeys") {
                return request.key
            } else {
                return nil
            }
        })
    }

    private func setupFirebase() {
        let optionsFile: String = {
            switch Current.appConfiguration {
            case .beta: return "GoogleService-Info-Beta"
            case .debug, .fastlaneSnapshot: return "GoogleService-Info-Debug"
            case .release: return "GoogleService-Info-Release"
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

    private func setupModels() {
        // Force Realm migration to happen now
        _ = Realm.live()

        Current.modelManager.cleanup().cauterize()
        Current.modelManager.subscribe()
        Action.setupObserver()
        NotificationCategory.setupObserver()
        WidgetOpenPageIntent.setupObserver()

        // TODO: Migrate observers to save values in GRDB
        ScriptsObserver.setupObserver()
        ScenesObserver.setupObserver()
    }

    private func setupMenus() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuRelatedSettingDidChange(_:)),
            name: SettingsStore.menuRelatedSettingDidChange,
            object: nil
        )
    }

    @objc private func menuRelatedSettingDidChange(_ note: Notification) {
        UIMenuSystem.main.setNeedsRebuild()
    }

    // swiftlint:disable:next file_length
}
