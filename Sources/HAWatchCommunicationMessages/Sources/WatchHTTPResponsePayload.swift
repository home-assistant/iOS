import Foundation

/// Payload of an `httpRequestResponse` message (phone → watch): the outcome of a relayed HTTP
/// request. Key names cross the wire — never rename them.
public enum WatchHTTPResponsePayload: Equatable {
    /// The phone reached the server. The status is whatever it answered, 2xx or not — a 401 is a
    /// successful relay carrying a rejected token, and the watch handles it exactly as it would
    /// have on its own.
    case response(statusCode: Int, headers: [String: String], body: Data)
    /// The phone could not hand back a response.
    case failure(Failure, reason: String)

    public enum Failure: String {
        /// The phone couldn't decode the request — the two builds disagree about the wire format.
        case malformedRequest
        /// No server on the phone matches the request's `serverId` — the watch is configured with a
        /// server the phone has since removed.
        case unknownServer
        /// The response was larger than `sendMessage` can carry back (see `WatchMessageSizeLimits`).
        case tooLarge
        /// The phone put the request on the network and it failed there.
        case transport

        /// Whether the phone had already put the request on the network when it failed this way.
        ///
        /// This is what decides whether the watch may repeat the request itself. After
        /// `transport` and `tooLarge` the server has seen it — `tooLarge` in particular means it
        /// *succeeded* and only the answer wouldn't fit back down the link — so repeating a
        /// non-idempotent request would run the action a second time. The rest fail before
        /// anything is sent, leaving the watch no worse off than without the relay at all.
        public var didReachNetwork: Bool {
            switch self {
            case .transport, .tooLarge:
                return true
            case .malformedRequest, .unknownServer:
                return false
            }
        }
    }

    public init?(content: [String: Any]) {
        if let rawFailure = content["failure"] as? String, let failure = Failure(rawValue: rawFailure) {
            self = .failure(failure, reason: content["reason"] as? String ?? "")
            return
        }
        guard let statusCode = content["statusCode"] as? Int else {
            return nil
        }
        self = .response(
            statusCode: statusCode,
            headers: content["headers"] as? [String: String] ?? [:],
            body: content["body"] as? Data ?? Data()
        )
    }

    public var content: [String: Any] {
        switch self {
        case let .response(statusCode, headers, body):
            return [
                "statusCode": statusCode,
                "headers": headers,
                "body": body,
            ]
        case let .failure(failure, reason):
            return [
                "failure": failure.rawValue,
                "reason": reason,
            ]
        }
    }
}
