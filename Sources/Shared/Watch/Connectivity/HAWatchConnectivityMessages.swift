import Foundation

public extension HAWatchConnectivity {
    /// A one-way message, and also the payload type delivered to / sent from an interactive reply.
    struct ImmediateMessage {
        public let identifier: String
        public let content: Content
        /// Protocol version of the build that sent this message; `nil` for messages from builds
        /// that predate versioning (and for locally constructed, not-yet-sent messages).
        public let senderVersion: Int?

        public init(identifier: String, content: Content = [:]) {
            self.identifier = identifier
            self.content = content
            self.senderVersion = nil
        }

        init?(content envelope: Content) {
            guard let identifier = envelope[PayloadKey.identifier] as? String,
                  let payload = envelope[PayloadKey.content] as? Content else {
                return nil
            }
            self.identifier = identifier
            self.content = payload
            self.senderVersion = envelope[PayloadKey.version] as? Int
        }

        func jsonRepresentation() -> Content {
            [
                PayloadKey.identifier: identifier,
                PayloadKey.content: content,
                PayloadKey.version: WatchProtocolVersion.current,
            ]
        }
    }

    /// A request/reply message. On the send side `reply` is the sender's response handler; on the
    /// receive side `reply` sends the response back to the counterpart (call-once, via `ReplyBox`).
    struct InteractiveImmediateMessage {
        public typealias Reply = (ImmediateMessage) -> Void

        public let identifier: String
        public let content: Content
        /// Protocol version of the build that sent this message; `nil` for messages from builds
        /// that predate versioning (and for locally constructed, not-yet-sent messages).
        public let senderVersion: Int?
        public let reply: Reply

        public init(identifier: String, content: Content = [:], reply: @escaping Reply) {
            self.identifier = identifier
            self.content = content
            self.senderVersion = nil
            self.reply = reply
        }

        init?(content envelope: Content, wcReplyHandler: @escaping ([String: Any]) -> Void) {
            guard let identifier = envelope[PayloadKey.identifier] as? String,
                  let payload = envelope[PayloadKey.content] as? Content else {
                return nil
            }
            self.identifier = identifier
            self.content = payload
            self.senderVersion = envelope[PayloadKey.version] as? Int
            let box = ReplyBox(wcReplyHandler)
            self.reply = { box.reply($0) }
        }

        func jsonRepresentation() -> Content {
            [
                PayloadKey.identifier: identifier,
                PayloadKey.content: content,
                PayloadKey.version: WatchProtocolVersion.current,
            ]
        }
    }

    /// A reliable, queued message (backed by `transferUserInfo`); delivered even when not reachable.
    struct GuaranteedMessage {
        public let identifier: String
        public let content: Content
        /// Protocol version of the build that sent this message; `nil` for messages from builds
        /// that predate versioning (and for locally constructed, not-yet-sent messages).
        public let senderVersion: Int?

        public init(identifier: String, content: Content = [:]) {
            self.identifier = identifier
            self.content = content
            self.senderVersion = nil
        }

        init?(content envelope: Content) {
            guard let identifier = envelope[PayloadKey.identifier] as? String,
                  let payload = envelope[PayloadKey.content] as? Content else {
                return nil
            }
            self.identifier = identifier
            self.content = payload
            self.senderVersion = envelope[PayloadKey.version] as? Int
        }

        func jsonRepresentation() -> Content {
            [
                PayloadKey.identifier: identifier,
                PayloadKey.content: content,
                PayloadKey.version: WatchProtocolVersion.current,
            ]
        }
    }
}

/// Wraps a raw WatchConnectivity reply handler so it fires at most once. A dropped-second-reply is
/// logged rather than trapping; a never-called reply lets the sender time out (WatchConnectivity's own
/// behavior).
final class ReplyBox {
    private let lock = NSLock()
    private var handler: (([String: Any]) -> Void)?

    init(_ handler: @escaping ([String: Any]) -> Void) {
        self.handler = handler
    }

    func reply(_ response: HAWatchConnectivity.ImmediateMessage) {
        lock.lock()
        let handlerToCall = handler
        handler = nil
        lock.unlock()

        if let handlerToCall {
            let envelope = response.jsonRepresentation()
            // Replies share sendMessage's payload ceiling; an oversized one surfaces on the
            // counterpart only as a reply timeout, so name the culprit here.
            WatchConnectivityManager.warnIfExceedsMessageLimit(envelope, identifier: response.identifier)
            handlerToCall(envelope)
        } else {
            Current.Log.error("WatchConnectivity reply invoked more than once for \(response.identifier)")
        }
    }
}
