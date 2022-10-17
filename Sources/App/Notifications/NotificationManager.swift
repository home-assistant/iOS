import CallbackURLKit
import Communicator
import FirebaseMessaging
import Foundation
import PromiseKit
import Shared
import UserNotifications
import XCGLogger

class NotificationManager: NSObject, LocalPushManagerDelegate {
    lazy var localPushManager: NotificationManagerLocalPushInterface = {
        if Current.isCatalyst {
            return NotificationManagerLocalPushInterfaceDirect(delegate: self)
        } else if #available(iOS 14, *) {
            return NotificationManagerLocalPushInterfaceExtension()
        } else {
            return NotificationManagerLocalPushInterfaceDisallowed()
        }
    }()

    var commandManager = NotificationCommandManager()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        _ = localPushManager
    }

    @objc private func didBecomeActive() {
        if Current.settingsStore.clearBadgeAutomatically {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func resetPushID() -> Promise<String> {
        firstly {
            Promise<Void> { seal in
                Messaging.messaging().deleteToken(completion: seal.resolve)
            }
        }.then {
            Promise<String> { seal in
                Messaging.messaging().token(completion: seal.resolve)
            }
        }
    }

    func setupFirebase() {
        Current.Log.verbose("Calling UIApplication.shared.registerForRemoteNotifications()")
        UIApplication.shared.registerForRemoteNotifications()

        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = Current.settingsStore.privacy.messaging
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        Current.Log.error("failed to register for remote notifications: \(error)")
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Current.Log.verbose("Successfully registered for push notifications! APNS token: \(apnsToken)")
        Current.crashReporter.setUserProperty(value: apnsToken, name: "APNS Token")

        var tokenType: MessagingAPNSTokenType = .prod

        if Current.appConfiguration == .Debug {
            tokenType = .sandbox
        }

        Messaging.messaging().setAPNSToken(deviceToken, type: tokenType)
    }

    func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(userInfo)

        firstly {
            handleRemoteNotification(userInfo: userInfo)
        }.done(
            completionHandler
        )
    }

    func localPushManager(
        _ manager: LocalPushManager,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) {
        handleRemoteNotification(userInfo: userInfo).cauterize()
    }

    private func handleRemoteNotification(userInfo: [AnyHashable: Any]) -> Guarantee<UIBackgroundFetchResult> {
        Current.Log.verbose("remote notification: \(userInfo)")

        return commandManager.handle(userInfo).map {
            UIBackgroundFetchResult.newData
        }.recover { _ in
            Guarantee<UIBackgroundFetchResult>.value(.failed)
        }
    }

    fileprivate func handleShortcutNotification(
        _ shortcutName: String,
        _ shortcutDict: [String: String]
    ) {
        var inputParams: CallbackURLKit.Parameters = shortcutDict
        inputParams["name"] = shortcutName

        Current.Log.verbose("Sending params in shortcut \(inputParams)")

        let eventName = "ios.shortcut_run"
        let deviceDict: [String: String] = [
            "sourceDevicePermanentID": Constants.PermanentID, "sourceDeviceName": UIDevice.current.name,
            "sourceDeviceID": Current.settingsStore.deviceID,
        ]
        var eventData: [String: Any] = ["name": shortcutName, "input": shortcutDict, "device": deviceDict]

        var successHandler: CallbackURLKit.SuccessCallback?

        if shortcutDict["ignore_result"] == nil {
            successHandler = { params in
                Current.Log.verbose("Received params from shortcut run \(String(describing: params))")
                eventData["status"] = "success"
                eventData["result"] = params?["result"]

                Current.Log.verbose("Success, sending data \(eventData)")

                when(fulfilled: Current.apis.map { api in
                    api.CreateEvent(eventType: eventName, eventData: eventData)
                }).catch { error in
                    Current.Log.error("Received error from createEvent during shortcut run \(error)")
                }
            }
        }

        let failureHandler: CallbackURLKit.FailureCallback = { error in
            eventData["status"] = "failure"
            eventData["error"] = error.XCUErrorParameters

            when(fulfilled: Current.apis.map { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }).catch { error in
                Current.Log.error("Received error from createEvent during shortcut run \(error)")
            }
        }

        let cancelHandler: CallbackURLKit.CancelCallback = {
            eventData["status"] = "cancelled"

            when(fulfilled: Current.apis.map { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }).catch { error in
                Current.Log.error("Received error from createEvent during shortcut run \(error)")
            }
        }

        do {
            try Manager.shared.perform(
                action: "run-shortcut",
                urlScheme: "shortcuts",
                parameters: inputParams,
                onSuccess: successHandler,
                onFailure: failureHandler,
                onCancel: cancelHandler
            )
        } catch let error as NSError {
            Current.Log.error("Running shortcut failed \(error)")

            eventData["status"] = "error"
            eventData["error"] = error.localizedDescription

            when(fulfilled: Current.apis.map { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }).catch { error in
                Current.Log.error("Received error from CallbackURLKit perform \(error)")
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    private func urlString(from response: UNNotificationResponse) -> String? {
        let content = response.notification.request.content
        let urlValue = ["url", "uri", "clickAction"].compactMap { content.userInfo[$0] }.first

        if let action = content.userInfoActionConfigs.first(
            where: { $0.identifier.lowercased() == response.actionIdentifier.lowercased() }
        ), let url = action.url {
            // we only allow the action-specific one to override global if it's set
            return url
        } else if let openURLRaw = urlValue as? String {
            // global url [string], always do it if we aren't picking a specific action
            return openURLRaw
        } else if let openURLDictionary = urlValue as? [String: String] {
            // old-style, per-action url -- for before we could define actions in the notification dynamically
            return openURLDictionary.compactMap { key, value -> String? in
                if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
                   key.lowercased() == NotificationCategory.FallbackActionIdentifier {
                    return value
                } else if key.lowercased() == response.actionIdentifier.lowercased() {
                    return value
                } else {
                    return nil
                }
            }.first
        } else {
            return nil
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(response.notification.request.content.userInfo)

        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else {
            Current.Log.info("ignoring dismiss action for notification")
            completionHandler()
            return
        }

        let userInfo = response.notification.request.content.userInfo

        Current.Log.verbose("User info in incoming notification \(userInfo) with response \(response)")

        guard let server = Current.servers.server(for: response.notification.request.content) else {
            Current.Log.info("ignoring push when unable to find server")
            completionHandler()
            return
        }

        if let shortcutDict = userInfo["shortcut"] as? [String: String],
           let shortcutName = shortcutDict["name"] {
            handleShortcutNotification(shortcutName, shortcutDict)
        }

        if let url = urlString(from: response) {
            Current.Log.info("launching URL \(url)")
            Current.sceneManager.webViewWindowControllerPromise.done {
                $0.open(from: .notification, server: server, urlString: url)
            }
        }

        if let info = HomeAssistantAPI.PushActionInfo(response: response) {
            Current.backgroundTask(withName: "handle-push-action") { _ in
                Current.api(for: server).handlePushAction(for: info)
            }.ensure {
                completionHandler()
            }.catch { err in
                Current.Log.error("Error when handling push action: \(err)")
            }
        } else {
            completionHandler()
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
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

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        let view = NotificationSettingsViewController()
        view.doneButton = true

        Current.sceneManager.webViewWindowControllerPromise.done {
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

extension NotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let loggableCurrent = Current.settingsStore.pushID ?? "(null)"
        let loggableNew = fcmToken ?? "(null)"

        Current.Log.info("Firebase registration token refreshed, new token: \(loggableNew)")

        if loggableCurrent != loggableNew {
            Current.Log.warning("FCM token has changed from \(loggableCurrent) to \(loggableNew)")
        }

        Current.crashReporter.setUserProperty(value: fcmToken, name: "FCM Token")
        Current.settingsStore.pushID = fcmToken

        Current.backgroundTask(withName: "notificationManager-didReceiveRegistrationToken") { _ in
            when(fulfilled: Current.apis.map { api in
                api.updateRegistration()
            })
        }.cauterize()
    }
}
