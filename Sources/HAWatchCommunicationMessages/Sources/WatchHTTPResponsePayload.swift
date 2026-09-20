import Foundation

/// Payload of an `httpRequestResponse` message (phone → watch): the outcome of a relayed HTTP
/// request. Key names cross the wire — never rename them.
public enum WatchHTTPResponsePayload {
    /// The phone reached the server. The status is whatever it answered, 2xx or not — a 401 is a
    /// successful relay carrying a rejected token, and the watch handles it exactly as it would
    /// have on its own.
    case response(statusCode: Int, headers: [String: String], body: Data)
    /// The phone could not hand back a response.
    case failure(Failure, reason: String)

    public enum Failure: String {
        /// This build of the iPhone app doesn't accept relayed requests. Distinct from the other
        /// pre-network failures in that it will not change for the life of the session, so the
        /// watch stops asking rather than paying a round trip per request.
        case notEnabled
        /// The phone couldn't decode the request — the two builds disagree about the wire format.
        case malformedRequest
        /// No server on the phone matches the request's `serverId` — the watch is configured with a
        /// server the phone has since removed.
        case unknownServer
        /// The response was larger than `sendMessage` can carry back (see `WatchMessageSizeLimits`).
        case tooLarge
        /// The phone put the request on the network and it failed there.
        case transport

        /// Whether the watch should fall back to performing the request over its own networking.
        ///
        /// `transport` doesn't: the phone did reach the network and the request failed on it, so a
        /// retry from the watch — which, when the phone is this reachable, is almost certainly
        /// routing through that same phone anyway — would just pay the timeout twice. Every other
        /// case means the phone never got as far as the network, so the watch is no worse off
        /// trying than it would have been without the relay at all.
        public var allowsDirectRetry: Bool {
            switch self {
            case .notEnabled, .malformedRequest, .unknownServer, .tooLarge:
                return true
            case .transport:
                return false
            }
        }

        /// Whether the watch should stop relaying altogether rather than just retry this one
        /// request. Only `notEnabled` says something about the phone that won't change.
        public var disablesRelay: Bool {
            self == .notEnabled
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
