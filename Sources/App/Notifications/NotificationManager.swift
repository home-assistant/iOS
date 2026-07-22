import CallbackURLKit
import FirebaseMessaging
import Foundation
import MediaPlayer
import PromiseKit
import Shared
import SwiftUI
import UserNotifications
import XCGLogger

#if DEBUG
private let forceDisableLocalPushForLiveActivityTesting = false
#endif

class NotificationManager: NSObject, LocalPushManagerDelegate {
    lazy var localPushManager: NotificationManagerLocalPushInterface = {
        #if DEBUG
        if forceDisableLocalPushForLiveActivityTesting {
            return NotificationManagerLocalPushInterfaceDisallowed()
        }
        #endif

        #if targetEnvironment(simulator)
        return NotificationManagerLocalPushInterfaceDirect(delegate: self)
        #else
        if Current.isCatalyst {
            return NotificationManagerLocalPushInterfaceDirect(delegate: self)
        } else {
            return NotificationManagerLocalPushInterfaceExtension()
        }
        #endif
    }()

    var commandManager = NotificationCommandManager()
    private weak var cameraOverlayController: UIViewController?
    private var displayedCamera: (entityId: String, serverIdentifier: Identifier<Server>)?

    /// Hidden, off-screen volume view; `MPVolumeView` only drives the hardware volume while in a window.
    private lazy var volumeControlView = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))

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
        if Manager.shared.callbackURLScheme == nil {
            Manager.shared.callbackURLScheme = Manager.urlSchemes?.first
        }
    }

    @objc private func didBecomeActive() {
        if Current.settingsStore.clearBadgeAutomatically {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        localPushManager.scheduleAppOpenLocalPushRetries()
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 17.2, *) {
            // Catch ends and starts enqueued by the extension while the app was suspended.
            LiveActivityPendingEndObserver.drain()
            LiveActivityPendingStartObserver.drain()
        }
        #endif
    }

    private func openCamera(from userInfo: [AnyHashable: Any]?) {
        guard let entityId = cameraEntityId(from: userInfo) else {
            Current.Log.error("Received kiosk_show_camera command without a valid camera entity_id")
            return
        }

        Current.sceneManager.webViewControllerPromise
            .done { [weak self] webViewController in
                guard let self else { return }
                let server = cameraServer(from: userInfo, fallback: webViewController.server)

                if let displayedCamera,
                   displayedCamera.entityId == entityId,
                   displayedCamera.serverIdentifier == server.identifier,
                   cameraOverlayController != nil {
                    Current.Log
                        .info("Ignoring kiosk_show_camera command because camera \(entityId) is already on display")
                    return
                }

                let view = CameraPlayerView(
                    server: server,
                    cameraEntityId: entityId
                )
                .onDisappear { [weak self] in
                    guard let self else { return }
                    // Only clear state if this overlay is still the active one. When switching
                    // directly from one camera to another, the old overlay's onDisappear fires
                    // after displayedCamera has already been updated for the new camera, so
                    // clearing unconditionally would wipe the new state and desync the flag.
                    guard displayedCamera?.entityId == entityId,
                          displayedCamera?.serverIdentifier == server.identifier else {
                        return
                    }
                    displayedCamera = nil
                    Current.kiosk.setCameraOverlayVisible(false)
                }
                .embeddedInHostingController()
                cameraOverlayController = view
                displayedCamera = (entityId: entityId, serverIdentifier: server.identifier)
                view.modalPresentationStyle = .overFullScreen
                Current.kiosk.setCameraOverlayVisible(true)
                webViewController.presentOverlayController(controller: view, animated: true)
            }.catch { [weak self] error in
                self?.displayedCamera = nil
                Current.kiosk.setCameraOverlayVisible(false)
                Current.Log.error("Failed to show camera from push command: \(error)")
            }
    }

    private func cameraEntityId(from userInfo: [AnyHashable: Any]?) -> String? {
        guard let userInfo else { return nil }

        if let entityId = userInfo["entity_id"] as? String, entityId.hasPrefix("camera.") {
            return entityId
        }

        if let homeassistant = userInfo["homeassistant"] as? [String: Any],
           let entityId = homeassistant["entity_id"] as? String,
           entityId.hasPrefix("camera.") {
            return entityId
        }

        if let homeassistant = userInfo["homeassistant"] as? [AnyHashable: Any],
           let entityId = homeassistant["entity_id"] as? String,
           entityId.hasPrefix("camera.") {
            return entityId
        }

        return nil
    }

    private func webhookId(from userInfo: [AnyHashable: Any]?) -> String? {
        guard let userInfo else { return nil }

        if let webhookId = userInfo["webhook_id"] as? String {
            return webhookId
        }

        if let homeassistant = userInfo["homeassistant"] as? [String: Any] {
            return homeassistant["webhook_id"] as? String
        }

        if let homeassistant = userInfo["homeassistant"] as? [AnyHashable: Any] {
            return homeassistant["webhook_id"] as? String
        }

        return nil
    }

    private func cameraServer(from userInfo: [AnyHashable: Any]?, fallback: Server) -> Server {
        guard let webhookId = webhookId(from: userInfo),
              let server = Current.servers.server(forWebhookID: webhookId) else {
            return fallback
        }

        return server
    }

    private func hideCamera() {
        Current.sceneManager.webViewControllerPromise
            .done { [weak self] webViewController in
                guard let cameraOverlayController = self?.cameraOverlayController,
                      webViewController.overlayedController === cameraOverlayController else {
                    Current.Log.info("Ignoring kiosk_hide_camera command because no camera is on display")
                    Current.kiosk.setCameraOverlayVisible(false)
                    return
                }

                webViewController.dismissOverlayController(animated: true) { [weak self] in
                    self?.cameraOverlayController = nil
                    self?.displayedCamera = nil
                    Current.kiosk.setCameraOverlayVisible(false)
                }
            }.catch { error in
                Current.Log.error("Failed to hide camera from push command: \(error)")
            }
    }

    private func setScreenBrightness(_ level: Float) {
        let clamped = CGFloat(min(max(level, 0), 1))
        DispatchQueue.main.async {
            UIScreen.main.brightness = clamped
            Current.Log.info("Kiosk set screen brightness to \(clamped)")
        }
    }

    private func setSystemVolume(_ level: Float) {
        let clamped = min(max(level, 0), 1)
        Current.sceneManager.webViewControllerPromise
            .done(on: .main) { [weak self] webViewController in
                guard let self else { return }
                if volumeControlView.superview == nil {
                    webViewController.view.addSubview(volumeControlView)
                }
                // The slider only exists once the view is in the hierarchy, so read it on the next loop.
                DispatchQueue.main.async {
                    guard let slider = self.volumeControlView.subviews.compactMap({ $0 as? UISlider }).first else {
                        Current.Log.error("Unable to locate system volume slider for kiosk command")
                        return
                    }
                    slider.setValue(clamped, animated: false)
                    slider.sendActions(for: .touchUpInside)
                    Current.Log.info("Kiosk set system volume to \(clamped)")
                }
            }.catch { error in
                Current.Log.error("Failed to set volume from push command: \(error)")
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

        if Current.appConfiguration == .debug {
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
            "sourceDevicePermanentID": AppConstants.PermanentID, "sourceDeviceName": UIDevice.current.name,
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

        #if DEBUG
        if response.actionIdentifier == NotificationSnoozeAction.debugTenSecondsActionIdentifier {
            Current.notificationDispatcher.reschedule(response.notification.request.content, after: 10)
            completionHandler()
            return
        }
        #endif

        // Snooze is an on-device-only convenience: reschedule a local re-delivery of the same
        // notification (so it keeps its snooze actions) and skip forwarding to Home Assistant.
        if let minutes = NotificationSnoozeAction.minutes(fromActionIdentifier: response.actionIdentifier) {
            Current.notificationDispatcher.reschedule(
                response.notification.request.content,
                after: TimeInterval(minutes) * 60
            )
            completionHandler()
            return
        }

        let userInfo = response.notification.request.content.userInfo

        Current.Log.verbose("User info in incoming notification \(userInfo) with response \(response)")

        // A tap must still run any HA command the notification carries. willPresent covers the
        // foreground path; this covers taps from the background/lock screen. Notably, a
        // `live_update` Live Activity start delivered over local push is handled by the
        // PushProvider extension (which can't touch ActivityKit), so without this a tap would
        // never start the activity. Fire-and-forget: it's independent of the tap routing below.
        if let hadict = userInfo["homeassistant"] as? [String: Any],
           (hadict["command"] as? String) != nil || (hadict["live_update"] as? Bool) == true {
            commandManager.handle(userInfo).cauterize()
        }

        if Current.kiosk.settings.acceptRemoteCommands,
           KioskPushCommand(message: response.notification.request.content.body) == .showCamera,
           cameraEntityId(from: userInfo) != nil {
            openCamera(from: userInfo)
            completionHandler()
            return
        }

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
            Current.sceneManager.appCoordinator.done {
                $0.open(from: .notification, server: server, urlString: url, isComingFromAppIntent: false)
            }
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
                  let entityId = userInfo["entity_id"] as? String,
                  let entityURL = AppConstants.openEntityDeeplinkURL(
                      entityId: entityId,
                      serverId: server.identifier.rawValue
                  ) {
            // No tap action was specified, so open the notification's entity on the server it
            // came from.
            Current.Log.info("opening entity \(entityId) from notification tap")
            Current.sceneManager.appCoordinator.done { _ in
                URLOpener.shared.open(entityURL, options: [:], completionHandler: nil)
            }
        }

        if let info = HomeAssistantAPI.PushActionInfo(response: response) {
            Current.backgroundTask(withName: BackgroundTask.handlePushAction.rawValue) { _ in
                Current.api(for: server)?
                    .handlePushAction(for: info) ?? .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
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

        // Handle commands (including Live Activities) for foreground notifications.
        // didReceiveRemoteNotification handles background pushes via Firebase/APNs,
        // but willPresent fires when the app is in the foreground. Without this,
        // notifications received while the app is open would never trigger the
        // Live Activity handler.
        // If a command is recognized, suppress the notification banner so the user
        // sees only the Live Activity (not a duplicate standard notification).
        if let hadict = notification.request.content.userInfo["homeassistant"] as? [String: Any],
           (hadict["command"] as? String) != nil || (hadict["live_update"] as? Bool) == true {
            commandManager.handle(notification.request.content.userInfo).done {
                // Play the chime if the notification has sound (non-silent live update),
                // but never show a banner — the Live Activity widget is the visual feedback.
                let options: UNNotificationPresentationOptions = notification.request.content.sound != nil
                    ? [.sound]
                    : []
                completionHandler(options)
            }.catch { error in
                // Unknown command — fall through to normal banner presentation so the user isn't silently swallowed.
                if case NotificationCommandManager.CommandError.unknownCommand = error {
                    completionHandler([.badge, .sound, .list, .banner])
                } else {
                    completionHandler([])
                }
            }
            return
        }

        if notification.request.content.userInfo[XCGLogger.notifyUserInfoKey] != nil,
           UIApplication.shared.applicationState != .background {
            completionHandler([])
            return
        }

        if let options = kioskPushPresentationOptions(for: notification) {
            completionHandler(options)
            return
        }

        var methods: UNNotificationPresentationOptions = [.badge, .sound, .list, .banner]
        if let presentationOptions = notification.request.content.userInfo["presentation_options"] as? [String] {
            methods = []
            if presentationOptions.contains("sound") || notification.request.content.sound != nil {
                methods.insert(.sound)
            }
            if presentationOptions.contains("badge") {
                methods.insert(.badge)
            }
            if presentationOptions.contains("list") {
                methods.insert(.list)
            }
            if presentationOptions.contains("banner") {
                methods.insert(.banner)
            }
        }
        return completionHandler(methods)
    }

    private func kioskPushPresentationOptions(
        for notification: UNNotification
    ) -> UNNotificationPresentationOptions? {
        let content = notification.request.content
        let message = content.body
        guard KioskPushCommand.isKioskCommand(message: message) else {
            return nil
        }

        guard Current.kiosk.settings.acceptRemoteCommands else {
            Current.Log.info("Ignoring kiosk remote command (disabled in settings): \(message)")
            return nil
        }

        guard let command = KioskPushCommand(message: message) else {
            Current.Log.warning("Unhandled kiosk push command, using default presentation: \(message)")
            return nil
        }

        performKioskCommand(command, userInfo: content.userInfo)

        if #available(iOS 18, *) {
            let identifier = notification.request.identifier
            let symbol = command.symbol
            let colors = (command.symbolForegroundStyle.primary, command.symbolForegroundStyle.secondary)
            let title = command.localizedString
            let subtitle = command.localizedSubtitle
            Task { @MainActor in
                ToastPresenter.shared.show(
                    id: identifier,
                    symbol: symbol,
                    symbolForegroundStyle: colors,
                    title: title,
                    message: subtitle,
                    duration: 4
                )
            }
        }

        return []
    }

    private func performKioskCommand(_ command: KioskPushCommand, userInfo: [AnyHashable: Any]) {
        switch command {
        case .showScreensaver:
            Current.kiosk.requestScreensaver(.show)
        case .hideScreensaver:
            Current.kiosk.requestScreensaver(.hide)
        case .showCamera:
            openCamera(from: userInfo)
        case .hideCamera:
            hideCamera()
        case .setBrightness:
            if let level = command.level(from: userInfo) {
                setScreenBrightness(level)
            } else {
                Current.Log.error("Ignoring \(command.rawValue): missing or invalid level in payload")
            }
        case .setVolume:
            if let level = command.level(from: userInfo) {
                setSystemVolume(level)
            } else {
                Current.Log.error("Ignoring \(command.rawValue): missing or invalid volume in payload")
            }
        case .setScreensaverMode:
            if let mode = command.screensaverMode(from: userInfo) {
                Current.kiosk.setScreensaverMode(mode)
            } else {
                Current.Log.error("Ignoring \(command.rawValue): missing or invalid mode in payload")
            }
        case .setScreensaverBrightness:
            if let level = command.level(from: userInfo) {
                Current.kiosk.setScreensaverDimLevel(Double(level))
            } else {
                Current.Log.error("Ignoring \(command.rawValue): missing or invalid level in payload")
            }
        case .reload:
            Current.sceneManager.webViewControllerPromise.done { $0.refresh() }
        case .defaultDashboard:
            returnToKioskDefault()
        }
    }

    /// Returns the kiosk to its configured server and dashboard. If the kiosk is pinned to a server
    /// other than the one on screen, switching to it rebuilds the web view (which loads the kiosk
    /// dashboard on creation); otherwise the current web view navigates to the configured dashboard.
    /// Mirrors `OnboardingStateObservable.applyKioskTarget(_:)`.
    private func returnToKioskDefault() {
        let serverId = Current.kioskSettings.serverId
        Current.sceneManager.webViewControllerPromise.done { webViewController in
            if let serverId, serverId != webViewController.server.identifier.rawValue,
               let server = Current.servers.server(forServerIdentifier: serverId) {
                Current.sceneManager.appCoordinator.done { $0.open(server: server) }
            } else {
                webViewController.applyKioskDashboard()
            }
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        let rootView = NavigationView {
            NotificationSettingsView(showsDoneButton: true)
        }
        .navigationViewStyle(.stack)
        let hostingController = rootView.embeddedInHostingController()

        Current.sceneManager.appCoordinator.done {
            var rootViewController = $0.window?.rootViewController
            if let navigationController = rootViewController as? UINavigationController {
                rootViewController = navigationController.viewControllers.first
            }
            rootViewController?.dismiss(animated: false, completion: {
                rootViewController?.present(hostingController, animated: true, completion: nil)
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

        Current.backgroundTask(withName: BackgroundTask.notificationManagerDidReceiveRegistrationToken.rawValue) { _ in
            when(fulfilled: Current.apis.map { api in
                api.updateRegistration()
            })
        }.cauterize()
    }
}
