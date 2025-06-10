import Foundation
import PromiseKit
import Shared
import UIKit
import WidgetKit

final class WebViewSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?
    var windowController: WebViewWindowController?
    var urlHandler: IncomingURLHandler?

    // swiftlint:disable cyclomatic_complexity
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }
        // if it tries to connect for an external display, decline -- it'll mirror instead
        guard session.role != .windowExternalDisplay else { return }

        ScaleFactorMutator.record(sceneIdentifier: session.persistentIdentifier)

        let window = UIWindow(haScene: scene)
        let windowController = WebViewWindowController(
            window: window,
            restorationActivity: session.stateRestorationActivity
        )
        let urlHandler = IncomingURLHandler(windowController: windowController)
        self.window = window
        self.windowController = windowController
        self.urlHandler = urlHandler

        with(scene.sizeRestrictions) {
            if scene.traitCollection.userInterfaceIdiom == .mac {
                $0?.minimumSize = CGSize(width: 250, height: 250)
            } else {
                $0?.minimumSize = CGSize(width: 300, height: 300)
            }
        }

        if Current.isCatalyst, Current.settingsStore.macNativeFeaturesOnly {
            // This getter does not exist on macOS 10.15, so we need to check that it responds.
            // Of course, this is not documented via availability headers, of course.
            if connectionOptions.responds(to: #selector(getter: UIScene.ConnectionOptions.shortcutItem)),
               let shortcutItem = connectionOptions.shortcutItem {
                self.windowScene(scene, performActionFor: shortcutItem, completionHandler: { _ in })
            } else if let url = Current.servers.all.first?.info.connection.activeURL() {
                UIApplication.shared.open(url)
                // Close window to avoid empty window left behind
                if let scene = window.windowScene {
                    UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil, errorHandler: nil)
                }
            }
        } else {
            windowController.setup()

            // This getter does not exist on macOS 10.15, so we need to check that it responds.
            // Of course, this is not documented via availability headers, of course.
            if connectionOptions.responds(to: #selector(getter: UIScene.ConnectionOptions.shortcutItem)),
               let shortcutItem = connectionOptions.shortcutItem {
                self.windowScene(scene, performActionFor: shortcutItem, completionHandler: { _ in })
            }
        }
        #if targetEnvironment(macCatalyst)
        if let titlebar = scene.titlebar {
            // disabling this also disables the "show tab bar" window tab bar (aka not uitabbar)
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }
        #endif

        if !connectionOptions.urlContexts.isEmpty {
            self.scene(scene, openURLContexts: connectionOptions.urlContexts)
        }

        if !connectionOptions.userActivities.isEmpty {
            for activity in connectionOptions.userActivities {
                self.scene(scene, continue: activity)
            }
        }

        informManager(from: connectionOptions)

        #if targetEnvironment(macCatalyst)
        WindowScenesManager.shared.sceneDidBecomeActive(scene)
        #endif
    }

    func sceneWillResignActive(_ scene: UIScene) {
        #if targetEnvironment(macCatalyst)
        WindowScenesManager.shared.sceneWillResignActive(scene)
        #endif

        DataWidgetsUpdater.update()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        windowController?.clearCachedControllers()
        windowController = nil
        window = nil
        urlHandler = nil

        #if targetEnvironment(macCatalyst)
        WindowScenesManager.shared.didDiscardScene(scene)
        #endif

        DataWidgetsUpdater.update()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        if #available(iOS 17.0, *) {
            // if a widget is pending confirmation to execute it's action
            // this will reset that and the widget will be restored to default state
            _ = ResetAllCustomWidgetConfirmationAppIntent()
        }
        DataWidgetsUpdater.update()
        Current.modelManager.unsubscribe()
        Current.appDatabaseUpdater.stop()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        updateDatabase()
        cleanWidgetsCache()
        updateLocation()
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        urlHandler?.handle(shortcutItem: shortcutItem)
            .done {
                completionHandler(true)
            }.catch { _ in
                completionHandler(false)
            }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for url in URLContexts.map(\.url) {
            urlHandler?.handle(url: url)
        }
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        windowController?.stateRestorationActivity()
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        urlHandler?.handle(userActivity: userActivity)
    }

    // MARK: - Private

    /// Whenever a custom widget is executed it can create cache files to hold it state,
    /// this clears it
    private func cleanWidgetsCache() {
        let widgetsCacheFile = AppConstants.widgetsCacheURL

        // Clean up widgets cache file
        do {
            try FileManager.default.removeItem(at: widgetsCacheFile)
        } catch {
            Current.Log.error("Failed to remove widgets cache file: \(error)")
        }
    }

    /// Sets up model manager and update database tables for cached panels and entities
    private func updateDatabase() {
        Current.modelManager.cleanup().cauterize()
        Current.modelManager.subscribe(isAppInForeground: {
            UIApplication.shared.applicationState == .active
        })

        Current.appDatabaseUpdater.update()
        Current.panelsUpdater.update()
    }

    /// Force update location when user opens the app
    private func updateLocation() {
        _ = HomeAssistantAPI.manuallyUpdate(
            applicationState: UIApplication.shared.applicationState,
            type: .appOpened
        )
    }
}
