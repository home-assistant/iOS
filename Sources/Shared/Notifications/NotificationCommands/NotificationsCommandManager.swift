import Communicator
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

    public enum CommandError: Error {
        case notCommand
        case unknownCommand
    }

    public init() {
        register(command: "request_location_update", handler: HandlerLocationUpdate())
        register(command: "clear_notification", handler: HandlerClearNotification())
        #if os(iOS)
        register(command: "update_complications", handler: HandlerUpdateComplications())
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
        // Try standard HA format first: { homeassistant: { command: "..." } }
        if let hadict = payload["homeassistant"] as? [String: Any],
           let command = hadict["command"] as? String {
            if let handler = commands[command] {
                return handler.handle(hadict)
            } else {
                return .init(error: CommandError.unknownCommand)
            }
        }

        // Fallback: check for command in aps.alert.body or message field
        // This supports simpler notification format where message IS the command
        let message: String? = {
            // Check aps.alert.body (standard APNS format)
            if let aps = payload["aps"] as? [String: Any],
               let alert = aps["alert"] as? [String: Any],
               let body = alert["body"] as? String {
                return body
            }
            // Check aps.alert as string
            if let aps = payload["aps"] as? [String: Any],
               let alert = aps["alert"] as? String {
                return alert
            }
            // Check message field directly
            if let msg = payload["message"] as? String {
                return msg
            }
            return nil
        }()

        if let message = message, message.hasPrefix("command_") {
            // Extract command from message
            let command = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if let handler = commands[command] {
                // Pass payload as context for any parameters
                var context = payload as? [String: Any] ?? [:]
                context["_parsed_from_body"] = true
                return handler.handle(context)
            }
        }

        return .init(error: CommandError.notCommand)
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
        Current.Log.verbose("clearing notification for \(payload)")
        let keys = ["tag", "collapseId"].compactMap { payload[$0] as? String }
        if !keys.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: keys)
        }
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
