import Alamofire
import CallbackURLKit
#if DEBUG && os(iOS)
import DebugSwift
#endif
import FirebaseCore
import FirebaseMessaging
import Intents
import KeychainAccess
import PromiseKit
#if os(iOS)
import SafariServices
#endif
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import WidgetKit
import XCGLogger

let keychain = AppConstants.Keychain

let prefs = UserDefaults(suiteName: AppConstants.AppGroupID)!

#if os(iOS)
private extension UIApplication {
    /// Under the SwiftUI `App` lifecycle `UIApplication.shared.delegate` is SwiftUI's own internal
    /// delegate — not the `@UIApplicationDelegateAdaptor`-managed `AppDelegate` — so the bare
    /// `delegate as! AppDelegate` cast aborts. Resolve via the recorded `AppDelegate.shared`.
    var typedDelegate: AppDelegate {
        guard let appDelegate = AppDelegate.shared else {
            // swiftlint:disable:next force_cast
            return delegate as! AppDelegate
        }
        return appDelegate
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
#else
extension AppEnvironment {
    // The adaptor creates the delegate before anything else in the app runs, so it is always there to ask.
    var sceneManager: SceneManager {
        AppDelegate.shared!.sceneManager
    }

    var notificationManager: NotificationManager {
        AppDelegate.shared!.notificationManager
    }
}
#endif

#if os(iOS)
// `@main` is on `HAApp`; this delegate is installed via `@UIApplicationDelegateAdaptor`.
class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Set from `init` so the adaptor-managed delegate stays reachable; see `UIApplication.typedDelegate`.
    private(set) static var shared: AppDelegate?

    let sceneManager = SceneManager()
    fileprivate let lifecycleManager = LifecycleManager()
    let notificationManager = NotificationManager()

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    #if DEBUG
    private let debugSwift = DebugSwift()
    #endif
    private var zoneManager: ZoneManager?
    #if targetEnvironment(macCatalyst)
    fileprivate let statusItemManager = StatusItemManager()
    #endif

    private var watchCommunicatorService: WatchCommunicatorService?
    private var liveActivityPendingEndObserver: Any?
    private var liveActivityPendingStartObserver: Any?

    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MaterialDesignIcons.register()

        guard !Current.isRunningTests else {
            return true
        }

        setDefaults()

        // swiftlint:disable prohibit_environment_assignment
        Current.backgroundTask = ApplicationBackgroundTaskRunner()

        // Initialize UIApplication wrapper for shared framework
        Current.application = {
            UIApplication.shared
        }

        Current.requestSensorPermissions = { uniqueIDs in
            Task { @MainActor in
                SensorPermissionRequester.shared.requestPermissionsIfNeeded(forSensorUniqueIDs: uniqueIDs)
            }
        }

        Current.isBackgroundRequestsImmediate = { [lifecycleManager] in
            if Current.isCatalyst {
                return false
            } else {
                return lifecycleManager.isActive
            }
        }

        #if targetEnvironment(macCatalyst)
        Current.tags = TagActivityManager()
        #elseif targetEnvironment(simulator)
        Current.tags = SimulatorTagManager()
        #else
        Current.tags = iOSTagManager()
        #endif
        // swiftlint:enable prohibit_environment_assignment

        notificationManager.setupNotifications()
        setupLiveActivityReattachment()
        setupFirebase()
        setupModels()
        setupLocalization()
        setupMenus()

        let launchingForLocation = launchOptions?[.location] != nil

        AnimatedSVGWebViewCache.shared
            .preloadOnFirstActivation(HomeAssistantStandByView.loadingLogoResourceName)

        let event = ClientEvent(
            text: "Application Starting" + (launchingForLocation ? " due to location change" : ""),
            type: .unknown
        )
        Current.clientEventStore.addEvent(event)

        zoneManager = ZoneManager()

        BackgroundRefreshManager.register()
        BackgroundRefreshManager.scheduleAppRefresh()
        RemindersSyncBackgroundRefresher.register()
        RemindersSyncBackgroundRefresher.schedule()

        setupWatchCommunicator()
        setupUIApplicationShortcutItems()
        migrateIfNeeded()
        RemindersSyncManager.shared.start()
        if #available(iOS 18.0, *) {
            SpotlightEntityIndexer.shared.start()
        }
        if #available(iOS 17.0, *) {
            HomeAssistantAppShortcuts.updateAppShortcutParameters()
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

        // Tints the remaining UIKit-backed switches (e.g. the Eureka settings forms) with the
        // brand color. SwiftUI toggles are no longer UISwitch-backed, so they get
        // `BrandedSwitchToggleStyle` at the hosting seams instead.
        UISwitch.appearance().onTintColor = .haPrimary

        lifecycleManager.didFinishLaunching()
        setupDebugSwift()
        FlightGreetingManager.shared.start()
        LocationBasedServerSwitcher.shared.start()

        #if targetEnvironment(macCatalyst)
        statusItemManager.configure()
        // Dock icon: when "Open Home Assistant UI in browser" is on there is no in-app web view, so a
        // reopen with no windows (Dock icon click) should open the browser instead of creating a window.
        Current.macBridge.setReopenHandler { StatusItemPrimaryAction.openInBrowserIfNeeded() }
        #endif

        checkForUpdate()
        checkForAlerts()

        return true
    }

    private func setupDebugSwift() {
        #if DEBUG
        // Opt-in via the "-EnableDebugSwift" launch argument (off by default). DebugSwift's
        // network monitor swizzles URLSessionConfiguration and intercepts every request, which
        // breaks mTLS / self-signed-certificate flows such as onboarding on the simulator.
        guard ProcessInfo.processInfo.arguments.contains("-EnableDebugSwift") else { return }
        debugSwift.setup()
        debugSwift.show()
        #endif
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        if builder.system == .main {
            let manager = MenuManager(builder: builder)
            manager.update()
        }
    }

    @objc func openMenuUrl(_ command: AnyObject) {
        guard let command = command as? UICommand, let url = MenuManager.url(from: command) else {
            return
        }

        // The primary window is SwiftUI-hosted now, so route through the coordinator (like the other
        // `webViewWindowControllerPromise` consumers) instead of looking up a UIKit scene delegate.
        sceneManager.appCoordinator.done { coordinator in
            IncomingURLHandler(coordinator: coordinator).handle(url: url)
        }
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == UISceneSession.Role.carTemplateApplication {
            return SceneActivity.carPlay.configuration
        } else {
            let activity = options.userActivities
                .compactMap { SceneActivity(activityIdentifier: $0.activityType) }
                .first ?? .webView

            if activity == .webView {
                // The primary window is owned by SwiftUI's `WindowGroup { ContainerView() }` (see `HAApp`).
                // The name MUST stay `WebView` (the shipped config name) — persisted scene sessions reference
                // it, and renaming it blanks the window on upgrade. `QuickActionWindowSceneDelegate` only
                // forwards Home-screen quick actions (it never owns a window), so SwiftUI still hosts the
                // scene; it restores quick-action handling lost when `WebViewSceneDelegate` was removed.
                let configuration = UISceneConfiguration(
                    name: "WebView",
                    sessionRole: connectingSceneSession.role
                )
                configuration.delegateClass = QuickActionWindowSceneDelegate.self
                return configuration
            }

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

    func applicationWillTerminate(_ application: UIApplication) {
        Current.forceCloseWarningManager.postImmediateWarning()
        // This prevents users from getting stuck on a page without a way to recover
        if !Current.isCatalyst {
            Current.settingsStore.lastActiveURLPath = nil
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
}
#else
// `@main` is on `HAApp`; this delegate is installed via `@NSApplicationDelegateAdaptor`.
class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set from `init` so the adaptor-managed delegate stays reachable from anywhere in the app.
    private(set) static var shared: AppDelegate?

    let sceneManager = SceneManager()
    fileprivate let lifecycleManager = LifecycleManager()
    let notificationManager = NotificationManager()
    fileprivate let statusItemManager = StatusItemManager()
    private var zoneManager: ZoneManager?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        MaterialDesignIcons.register()

        guard !Current.isRunningTests else {
            return
        }

        setDefaults()

        // swiftlint:disable prohibit_environment_assignment
        Current.requestSensorPermissions = { uniqueIDs in
            Task { @MainActor in
                SensorPermissionRequester.shared.requestPermissionsIfNeeded(forSensorUniqueIDs: uniqueIDs)
            }
        }

        Current.tags = TagActivityManager()
        // swiftlint:enable prohibit_environment_assignment

        notificationManager.setupNotifications()
        setupFirebase()
        setupModels()
        setupLocalization()
        setupMenus()

        AnimatedSVGWebViewCache.shared
            .preloadOnFirstActivation(HomeAssistantStandByView.loadingLogoResourceName)

        Current.clientEventStore.addEvent(ClientEvent(text: "Application Starting", type: .unknown))

        zoneManager = ZoneManager()

        BackgroundRefreshManager.register()
        BackgroundRefreshManager.scheduleAppRefresh()
        RemindersSyncBackgroundRefresher.register()
        RemindersSyncBackgroundRefresher.schedule()

        migrateIfNeeded()
        RemindersSyncManager.shared.start()
        if #available(macOS 15.0, *) {
            SpotlightEntityIndexer.shared.start()
        }
        if #available(macOS 14.0, *) {
            HomeAssistantAppShortcuts.updateAppShortcutParameters()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSClassFromString("XCTest") != nil {
            return
        }

        lifecycleManager.didFinishLaunching()
        FlightGreetingManager.shared.start()
        LocationBasedServerSwitcher.shared.start()

        statusItemManager.configure()

        checkForUpdate()
        checkForAlerts()
    }

    /// The menu behind the Dock icon, on top of the entries macOS puts there itself.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let openSettings = NSMenuItem(
            title: L10n.ShortcutItem.OpenSettings.title,
            action: #selector(openSettingsFromDock),
            keyEquivalent: ""
        )
        openSettings.target = self
        menu.addItem(openSettings)
        return menu
    }

    @objc private func openSettingsFromDock() {
        Current.sceneManager.activateAnyScene(for: .settings)
    }

    /// The Dock icon was clicked with no window on screen. When "Open Home Assistant UI in browser" is on
    /// there is no in-app web view to show, so the browser opens instead of a new window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, StatusItemPrimaryAction.openInBrowserIfNeeded() {
            return false
        }
        return true
    }

    /// Closing the last window leaves the app running: it keeps reporting sensors, and the menu bar item
    /// and Dock icon bring a window back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Posted before termination is under way, so whoever observes it can still start the work it needs
        // to finish, such as reporting that the Mac is no longer active; the reply waits for that work.
        NotificationCenter.default.post(name: Current.macBridge.terminationWillBeginNotification, object: nil)
        ProcessInfoBackgroundTaskRunner.whenIdle(
            after: Self.terminationSettleTime,
            timeout: Self.terminationGracePeriod
        ) {
            Current.Log.info("terminating with \(ProcessInfoBackgroundTaskRunner.inFlight) background tasks left")
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    /// How long the work the notification above starts gets to begin before an idle app quits.
    private static let terminationSettleTime: TimeInterval = 0.5
    private static let terminationGracePeriod: TimeInterval = 5

    func applicationWillTerminate(_ notification: Notification) {
        Current.forceCloseWarningManager.postImmediateWarning()
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        notificationManager.didFailToRegisterForRemoteNotifications(error: error)
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationManager.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        notificationManager.didReceiveRemoteNotification(userInfo: userInfo)
    }

    func application(_ application: NSApplication, handlerFor intent: INIntent) -> Any? {
        IntentHandlerFactory.handler(for: intent)
    }
}
#endif

// MARK: - Launch steps shared by the iOS and macOS delegates

extension AppDelegate {
    @objc func checkForUpdate(_ sender: AnyObject? = nil) {
        guard Current.updater.isSupported else { return }

        let dueToUserInteraction = sender != nil

        Current.updater.check(dueToUserInteraction: dueToUserInteraction).done { [sceneManager] update in
            let alert = AppAlert(
                title: L10n.Updater.UpdateAvailable.title,
                actions: [
                    .init(title: L10n.Updater.UpdateAvailable.open(update.name)) {
                        URLOpener.shared.open(update.htmlUrl, options: [:], completionHandler: nil)
                    },
                    .init(title: L10n.okLabel, style: .cancel),
                ]
            )

            sceneManager.appCoordinator.done {
                $0.present(alert: alert)
            }
        }.catch { [sceneManager] error in
            Current.Log.error("check error: \(error)")

            if dueToUserInteraction {
                let alert = AppAlert(
                    title: L10n.Updater.NoUpdatesAvailable.title,
                    message: error.localizedDescription,
                    actions: [.init(title: L10n.okLabel, style: .cancel)]
                )

                sceneManager.appCoordinator.done {
                    $0.present(alert: alert)
                }
            }
        }
    }

    private func checkForAlerts() {
        firstly {
            Current.serverAlerter.check(dueToUserInteraction: false)
        }.done { [sceneManager] alert in
            sceneManager.appCoordinator.done { controller in
                controller.show(alert: alert)
            }
        }.catch { error in
            Current.Log.error("check error: \(error)")
        }

        showNotificationCategoryAlertIfNeeded()
    }

    private func showNotificationCategoryAlertIfNeeded() {
        guard NotificationCategory.all().isEmpty == false else {
            return
        }

        let userDefaults = UserDefaults.standard
        let seenKey = "category-deprecation-3-" + Current.clientVersion().description

        guard !userDefaults.bool(forKey: seenKey) else {
            return
        }

        when(fulfilled: Current.apis.compactMap { $0.connection.caches.user.once().promise })
            .done { [sceneManager] users in
                guard users.contains(where: \.isAdmin) else {
                    Current.Log.info("not showing because not an admin anywhere")
                    return
                }

                let alert = Self.notificationCategoryDeprecationAlert(userDefaults: userDefaults, seenKey: seenKey)
                sceneManager.appCoordinator.done {
                    $0.present(alert: alert)
                }
            }.catch { error in
                Current.Log.error("couldn't check for if user: \(error)")
            }
    }

    /// Tells an admin that notification categories are now configured on the server. Either button marks
    /// the alert as seen so it stays away afterwards; the first one also opens the documentation.
    static func notificationCategoryDeprecationAlert(userDefaults: UserDefaults, seenKey: String) -> AppAlert {
        AppAlert(
            title: L10n.Alerts.Deprecations.NotificationCategory.title,
            message: L10n.Alerts.Deprecations.NotificationCategory.message("iOS-2022.4"),
            actions: [
                .init(title: L10n.Nfc.List.learnMore) {
                    userDefaults.set(true, forKey: seenKey)
                    openURLInBrowser(
                        URL(string: "https://companion.home-assistant.io/app/ios/actionable-notifications")!,
                        nil
                    )
                },
                .init(title: L10n.okLabel, style: .cancel) {
                    userDefaults.set(true, forKey: seenKey)
                },
            ]
        )
    }

    #if os(iOS)
    private func setupWatchCommunicator() {
        watchCommunicatorService = WatchCommunicatorService()
        watchCommunicatorService?.setup()
    }
    #endif

    func setupLocalization() {
        Current.localized.add(stringProvider: { request in
            if prefs.bool(forKey: "showTranslationKeys") {
                return request.key
            } else {
                return nil
            }
        })
    }

    #if os(iOS)
    private func setupLiveActivityReattachment() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 17.2, *) {
            // Pre-warm the registry on the main thread before spawning background Tasks.
            // This avoids a lazy-init race if a push notification handler accesses it
            // concurrently from a background thread.
            guard let registry = Current.liveActivityRegistry else { return }

            // Register before draining so ends/starts enqueued while the app was gone aren't missed.
            let pendingEndObserver = LiveActivityPendingEndObserver()
            liveActivityPendingEndObserver = pendingEndObserver
            pendingEndObserver.drain()

            // Starts handed off by the PushProvider extension (local-push live_update notifications,
            // which can't touch ActivityKit in-process). Drained here and on foreground.
            let pendingStartObserver = LiveActivityPendingStartObserver()
            liveActivityPendingStartObserver = pendingStartObserver
            pendingStartObserver.drain()

            Task {
                // Re-attach observation tasks (push token + lifecycle) to any Live Activities
                // that survived the previous process termination. Must run before the first
                // notification handler fires so no push token updates are missed.
                await registry.reattach()
            }

            // Begin observing the push-to-start token stream on a separate Task.
            // The stream is infinite; this Task is kept alive for the app's lifetime.
            Task {
                await registry.startObservingPushToStartToken()
            }

            // Observe activities that ActivityKit starts directly from APNs push-to-start.
            // The stream is infinite; this Task is kept alive for the app's lifetime.
            Task {
                await registry.startObservingRemoteActivityStarts()
            }
        }
        #endif
    }
    #endif

    private func setupFirebase() {
        let optionsFile: String = {
            switch Current.appConfiguration {
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
        // Import any legacy Realm data into GRDB before anything reads it
        RealmToGRDBMigration.migrateIfNeeded()
        NotificationCategory.setupObserver()
        // Start the server-state subscriptions that keep GRDB models in sync
        // (zones via the states cache); without this, appZone is never populated
        // and region monitoring has nothing to track.
        Current.modelManager.cleanup().cauterize()
        Current.modelManager.subscribe(isAppInForeground: {
            ApplicationState.current == .active
        })
    }

    private func setupMenus() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuRelatedSettingDidChange(_:)),
            name: SettingsStore.menuRelatedSettingDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(apiDidConnect(_:)),
            name: HomeAssistantAPI.didConnectNotification,
            object: nil
        )
    }

    @objc private func menuRelatedSettingDidChange(_ note: Notification) {
        #if os(iOS)
        UIMenuSystem.main.setNeedsRebuild()
        #endif
        #if targetEnvironment(macCatalyst) || os(macOS)
        statusItemManager.configure()
        #endif
    }

    @objc private func apiDidConnect(_ note: Notification) {
        #if os(iOS)
        UIMenuSystem.main.setNeedsRebuild()
        #endif
        #if targetEnvironment(macCatalyst) || os(macOS)
        statusItemManager.apiDidConnect()
        #endif
    }

    #if os(iOS)
    private func setupUIApplicationShortcutItems() {
        AppIconShortcutItemsUpdater.start()
    }
    #endif

    private func migrateIfNeeded() {
        resetLocalPush()
        resetShakeGesture()
        migrateRestoreLastURL()
    }

    /// Remember Last Page becomes opt-in (disabled by default); installs that already
    /// have a server configured keep the previous enabled-by-default behavior.
    private func migrateRestoreLastURL() {
        Current.settingsStore.migrateRestoreLastURLToOptInIfNeeded(
            hasExistingServers: !Current.servers.all.isEmpty
        )
    }

    /// Shake gesture no longer opens debug by default; users who had it set to debug are reset once to none.
    private func resetShakeGesture() {
        if !Current.settingsStore.migratedShakeGestureToNone {
            var gestures = Current.settingsStore.gestures
            if gestures[.shake] == .openDebug {
                gestures[.shake] = HAGestureAction.none
                Current.settingsStore.gestures = gestures
                Current.Log.info("Reset shake gesture from open debug to none due to migration")
            }
            Current.settingsStore.migratedShakeGestureToNone = true
        }
    }

    /// Local push becomes opt-in on 2025.6, users will have local push reset and need to re-enable it
    private func resetLocalPush() {
        if !Current.settingsStore.migratedOptInLocalPush {
            for server in Current.servers.all {
                server.update { info in
                    info.connection.isLocalPushEnabled = false
                }
            }
            Current.settingsStore.migratedOptInLocalPush = true
            Current.Log.info("Reset local push for all servers due to migration")
        } else {
            Current.Log.info("No need to reset local push, migration already done")
        }
    }

    // swiftlint:disable:next file_length
}
