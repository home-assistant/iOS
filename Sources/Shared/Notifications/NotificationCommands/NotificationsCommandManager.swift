import Communicator
import PromiseKit
import UserNotifications

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
    }

    private var commands = [String: NotificationCommandHandler]()

    public func register(command: String, handler: NotificationCommandHandler) {
        commands[command] = handler
    }

    public func handle(_ payload: [AnyHashable: Any]) -> Promise<Void> {
        guard let hadict = payload["homeassistant"] as? [String: Any],
              let command = hadict["command"] as? String else {
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

        return Current.backgroundTask(withName: "push-location-request") { remaining in
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
#endif
