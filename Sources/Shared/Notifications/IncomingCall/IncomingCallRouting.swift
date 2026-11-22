import Foundation

/// Chooses how an `incoming_call` notification reaches the user: as a phone call through CallKit, or as an
/// ordinary notification with Answer and Decline actions.
///
/// It decides once per delivery, where the notification arrives (`LocalPushManager` for local push, the app's
/// `willPresent` for a remote push received in the foreground), so the guard records each call a single time.
public enum IncomingCallRouting {
    public enum Route: Equatable {
        /// Ring through CallKit.
        case callKit(IncomingCallRequest)
        /// Show the notification as it is, without CallKit.
        case notification
    }

    public static func route(
        userInfo: [AnyHashable: Any],
        server: Server?,
        isEnabled: Bool = IncomingCallFeature.isEnabled,
        callGuard: IncomingCallGuard = .init()
    ) -> Route {
        guard IncomingCallRequest.isIncomingCall(userInfo: userInfo), isEnabled else {
            return .notification
        }

        guard let server else {
            Current.Log.info("incoming call from an unknown server, showing it as a notification")
            return .notification
        }

        let request: IncomingCallRequest
        switch IncomingCallRequest.parse(userInfo: userInfo, serverURLs: serverURLs(for: server)) {
        case let .success(parsed):
            request = parsed
        case let .failure(error):
            Current.Log.error("invalid incoming call (\(error)), showing it as a notification")
            return .notification
        }

        switch callGuard.admit(tag: request.tag) {
        case .ring:
            return .callKit(request)
        case .duplicate:
            Current.Log.info("incoming call \(request.tag) already rang, showing it as a notification")
            return .notification
        case .rateLimited:
            Current.Log.info("too many incoming calls, showing \(request.tag) as a notification")
            return .notification
        }
    }

    /// The notification without its `incoming_call` command, so it is presented like any other notification
    /// instead of being handled as a command. The rest of the `homeassistant` dictionary, and so the tag the
    /// Answer and Decline actions send back, is kept.
    public static func notificationOnly(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
        guard var hadict = userInfo["homeassistant"] as? [String: Any],
              (hadict["command"] as? String) == IncomingCallRequest.command else {
            return userInfo
        }
        var result = userInfo
        hadict["command"] = nil
        result["homeassistant"] = hadict
        return result
    }

    /// The addresses an `incoming_call` URL may point to: the server's own.
    public static func serverURLs(for server: Server) -> [URL] {
        let connection = server.info.connection
        return [ConnectionInfo.URLType.internal, .external, .remoteUI].compactMap { connection.address(for: $0) }
    }
}
