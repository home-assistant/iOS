import Communicator
import Foundation
import PromiseKit
import UserNotifications
import WidgetKit

public protocol NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void>
}

public class NotificationCommandManager {
    public static var didUpdateComplicationsNotification: Notification.Name {
        .init(rawValue: "didUpdateComplicationsNotification")
    }

    public static var didReceiveShowCameraNotification: Notification.Name {
        .init(rawValue: "didReceiveShowCameraNotification")
    }

    public static var didReceiveHideCameraNotification: Notification.Name {
        .init(rawValue: "didReceiveHideCameraNotification")
    }

    public enum CommandError: Error {
        case notCommand
        case unknownCommand
    }

    public init() {
        register(command: "request_location_update", handler: HandlerLocationUpdate())
        register(command: "clear_notification", handler: HandlerClearNotification())
        #if os(iOS)
        register(command: "update_complications", handler: HandlerUpdateComplications())
        register(command: "show_camera", handler: HandlerShowCamera())
        register(command: "hide_camera", handler: HandlerHideCamera())
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 17.2, *) {
            register(command: "live_activity", handler: HandlerStartOrUpdateLiveActivity())
        }
        #endif
        #endif

        #if os(iOS) || os(macOS)
        register(command: "update_widgets", handler: HandlerUpdateWidgets())
        #endif
    }

    private var commands = [String: NotificationCommandHandler]()

    public func register(command: String, handler: NotificationCommandHandler) {
        commands[command] = handler
    }

    public func handle(_ payload: [AnyHashable: Any]) -> Promise<Void> {
        guard var hadict = payload["homeassistant"] as? [String: Any] else {
            return .init(error: CommandError.notCommand)
        }

        if let webhookId = payload["webhook_id"] as? String {
            hadict["webhook_id"] = webhookId
        }

        // Support data.live_update: true — the same field Android uses for Live Updates.
        // A single YAML automation can target both platforms with no platform-specific keys.
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 17.2, *), hadict["live_update"] as? Bool == true,
           let handler = commands["live_activity"] {
            return handler.handle(hadict)
        }
        #endif

        guard let command = hadict["command"] as? String else {
            return .init(error: CommandError.notCommand)
        }

        if let handler = commands[command] {
            return handler.handle(hadict)
        } else {
            return .init(error: CommandError.unknownCommand)
        }
    }

    public func updateComplications() -> Promise<Void> {
        #if os(iOS)
        HandlerUpdateComplications().handle([:])
        #else
        return .value(())
        #endif
    }
}

private struct HandlerLocationUpdate: NotificationCommandHandler {
    private enum LocationUpdateError: Error {
        case notEnabled
    }

    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard Current.settingsStore.locationSources.pushNotifications else {
            Current.Log.info("ignoring request, location source of notifications is disabled")
            return .init(error: LocationUpdateError.notEnabled)
        }

        Current.Log.verbose("Received remote request to provide a location update")

        return Current.backgroundTask(withName: BackgroundTask.pushLocationRequest.rawValue) { remaining in
            firstly {
                Current.location.oneShotLocation(.PushNotification, remaining)
            }.then { location in
                when(fulfilled: Current.apis.map { api in
                    api.SubmitLocation(updateType: .PushNotification, location: location, zone: nil)
                })
            }
        }
    }
}

private struct HandlerClearNotification: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Current.Log.verbose("Clearing notification for \(payload)")
        let keys = ["tag", "collapseId"].compactMap { payload[$0] as? String }
        if !keys.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: keys)
        }

        // ActivityKit works only in the app, not the PushProvider extension, so the extension
        // hands the end off via the App Group queue + a Darwin signal for the app to drain.
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 17.2, *), let tag = payload["tag"] as? String, !tag.isEmpty {
            if Current.isAppExtension {
                Current.Log.verbose("Handing off live activity end for tag \(tag) to the app")
                LiveActivityPendingEnd.append(tag: tag)
                LiveActivityPendingEnd.postDarwinSignal()
                return .value(())
            }
            return Promise<Void> { seal in
                Task {
                    Current.Log.verbose("Clearing live activity for \(payload)")
                    await Current.liveActivityRegistry?.end(tag: tag, dismissalPolicy: .immediate)
                    // https://stackoverflow.com/a/56657888/6324550
                    DispatchQueue.main.async { seal.fulfill(()) }
                }
            }
        }
        #endif

        // https://stackoverflow.com/a/56657888/6324550
        return Promise<Void> { seal in
            DispatchQueue.main.async {
                seal.fulfill(())
            }
        }
    }
}

#if os(iOS)
private struct HandlerUpdateComplications: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Promise<Void> { seal in
            Communicator.shared.transfer(ComplicationInfo(content: [:])) { result in
                switch result {
                case .success: seal.fulfill(())
                case let .failure(error): seal.reject(error)
                }
            }
        }.get {
            NotificationCenter.default.post(
                name: NotificationCommandManager.didUpdateComplicationsNotification,
                object: nil
            )
        }
    }
}

private struct HandlerUpdateWidgets: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Current.Log.verbose("Reloading widgets triggered by notification command")
        Current.clientEventStore.addEvent(ClientEvent(
            text: "Notification command triggered widget update",
            type: .notification
        ))
        DataWidgetsUpdater.update()
        return Promise.value(())
    }
}
#endif
