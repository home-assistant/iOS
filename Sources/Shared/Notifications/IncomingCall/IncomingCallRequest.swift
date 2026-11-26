import Foundation

/// A validated `incoming_call` notification.
///
/// Built from the `homeassistant` dictionary the push parser produces for `message: incoming_call`, on both the
/// local-push and the remote-push flow. Everything here comes from an automation, so every field is checked
/// before it can reach CallKit, the lock screen or the web view:
///
/// - `tag` identifies the call. It follows the Live Activity tag rules (1–64 of `A–Z a–z 0–9 - _`), because it
///   is also the notification identifier that `clear_notification` uses to stop the ringing.
/// - `caller` is what the lock screen shows. Control characters and line breaks are removed and it is cut to
///   `maximumCallerLength` characters; an empty caller falls back to the server name.
/// - `url` is opened in the app when the call is answered. Only a path on the server that sent the call is
///   accepted (`/lovelace/0#visio`), or an absolute `http(s)` URL to one of that server's own addresses (same
///   scheme, host and effective port, no credentials), which is kept as its path so it opens in the app on the
///   server's current address. Anything else is dropped: answering then simply opens the app.
/// - The server is the one the notification was delivered for (its `webhook_id`); an `action_data.webhook_id`
///   from the automation never overrides it.
/// - `timeout` is how long the phone rings before the call counts as missed, clamped to `timeoutRange`.
public struct IncomingCallRequest: Equatable {
    public static let command = "incoming_call"
    public static let maximumCallerLength = 64
    public static let defaultTimeout: TimeInterval = 45
    public static let timeoutRange: ClosedRange<TimeInterval> = 10 ... 120

    /// Marks an `incoming_call` shown as a notification after its command was removed (`IncomingCallRouting`).
    public static let notificationMarker = "incoming_call_notification"

    /// Keys of the `homeassistant` dictionary that are not the automation's, and are never sent back in events.
    static let internalKeys = ["command", "webhook_id", "hass_confirm_id", notificationMarker]

    public enum ParseError: Error, Equatable {
        case notIncomingCall
        case invalidTag
    }

    public var tag: String
    public var caller: String?
    public var hasVideo: Bool
    public var url: String?
    public var timeout: TimeInterval
    public var webhookID: String?
    /// Sent back as `action_data` with every call event: the automation's own `action_data` and the call fields.
    public var actionData: [String: Any]

    public init(
        tag: String,
        caller: String?,
        hasVideo: Bool,
        url: String?,
        timeout: TimeInterval,
        webhookID: String?,
        actionData: [String: Any] = [:]
    ) {
        self.tag = tag
        self.caller = caller
        self.hasVideo = hasVideo
        self.url = url
        self.timeout = timeout
        self.webhookID = webhookID
        self.actionData = actionData
    }

    /// Parses the `homeassistant` dictionary of a notification. `serverURLs` are the addresses of the server the
    /// notification came from, used to accept absolute URLs that point back to it. `webhook_id` must be the
    /// delivery's, as `NotificationCommandManager` and `parse(userInfo:)` set it.
    ///
    /// `allowNotification` also accepts a call already shown as a notification (its command removed), to handle
    /// the Answer and Decline actions of that notification.
    public static func parse(
        homeassistant hadict: [String: Any],
        serverURLs: [URL] = [],
        allowNotification: Bool = false
    ) -> Result<IncomingCallRequest, ParseError> {
        let isCommand = (hadict["command"] as? String) == command
        let isNotification = allowNotification && (hadict[notificationMarker] as? Bool) == true
        guard isCommand || isNotification else {
            return .failure(.notIncomingCall)
        }

        guard let tag = hadict["tag"] as? String, isValidTag(tag) else {
            return .failure(.invalidTag)
        }

        // The notification fallback sends `userInfo["homeassistant"]` back as `action_data`, so the CallKit path
        // sends the same dictionary: the automation's `action_data` plus the call fields. Keys the app adds for
        // its own bookkeeping stay out of events.
        var actionData = hadict
        for key in internalKeys {
            actionData[key] = nil
        }

        return .success(.init(
            tag: tag,
            caller: sanitizedCaller(hadict["caller"]),
            hasVideo: hadict["video"] as? Bool ?? true,
            url: allowedURL(hadict["url"], serverURLs: serverURLs),
            timeout: clampedTimeout(hadict["timeout"]),
            webhookID: hadict["webhook_id"] as? String,
            actionData: actionData
        ))
    }

    /// Parses a full notification `userInfo`, as delivered to the app or the push extension.
    public static func parse(
        userInfo: [AnyHashable: Any],
        serverURLs: [URL] = [],
        allowNotification: Bool = false
    ) -> Result<IncomingCallRequest, ParseError> {
        guard var hadict = userInfo["homeassistant"] as? [String: Any] else {
            return .failure(.notIncomingCall)
        }
        // The server is the delivery's. `homeassistant` holds the automation's `action_data`, which must not be
        // able to name another server.
        hadict["webhook_id"] = userInfo["webhook_id"] as? String
        return parse(homeassistant: hadict, serverURLs: serverURLs, allowNotification: allowNotification)
    }

    /// Whether a notification carries the `incoming_call` command, valid or not.
    public static func isIncomingCall(userInfo: [AnyHashable: Any]) -> Bool {
        guard let hadict = userInfo["homeassistant"] as? [String: Any] else { return false }
        return (hadict["command"] as? String) == command
    }

    /// Whether a notification is an incoming call, carrying the command or already shown as a notification.
    public static func isIncomingCallNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let hadict = userInfo["homeassistant"] as? [String: Any] else { return false }
        return (hadict["command"] as? String) == command || (hadict[notificationMarker] as? Bool) == true
    }

    /// The same rules as Live Activity tags: they are notification identifiers too.
    public static func isValidTag(_ tag: String) -> Bool {
        guard !tag.isEmpty, tag.count <= 64 else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        return tag.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    static func sanitizedCaller(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let printable = String(String.UnicodeScalarView(raw.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) && !CharacterSet.newlines.contains($0)
        }))
        let collapsed = printable
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maximumCallerLength))
    }

    static func clampedTimeout(_ value: Any?) -> TimeInterval {
        let seconds: TimeInterval
        switch value {
        case let value as Int: seconds = TimeInterval(value)
        case let value as Double: seconds = value
        case let value as String: seconds = TimeInterval(value) ?? defaultTimeout
        default: seconds = defaultTimeout
        }
        guard seconds.isFinite else { return defaultTimeout }
        return min(max(seconds, timeoutRange.lowerBound), timeoutRange.upperBound)
    }

    /// Keeps a URL only when it stays on the server that sent the call, as a path on that server.
    static func allowedURL(_ value: Any?, serverURLs: [URL]) -> String? {
        guard let raw = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              raw.count <= 2048 else {
            return nil
        }

        // A path on the server: "/lovelace/0#visio". "//host/..." is a scheme-relative URL to another host.
        if raw.hasPrefix("/") {
            return raw.hasPrefix("//") || raw.contains("\\") ? nil : raw
        }

        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.user == nil, url.password == nil,
              let host = url.host?.lowercased(),
              let port = effectivePort(of: url) else {
            return nil
        }

        let isServerAddress = serverURLs.contains { serverURL in
            serverURL.scheme?.lowercased() == scheme &&
                serverURL.host?.lowercased() == host &&
                effectivePort(of: serverURL) == port
        }
        guard isServerAddress else { return nil }

        // Opened as a path on the server, so it loads in the app on whichever address is active right now.
        var path = url.path.isEmpty ? "/" : url.path
        if let query = url.query {
            path += "?" + query
        }
        if let fragment = url.fragment {
            path += "#" + fragment
        }
        return path
    }

    /// The port a URL connects to, spelled out or implied by its scheme.
    static func effectivePort(of url: URL) -> Int? {
        if let port = url.port {
            return port
        }
        switch url.scheme?.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }

    public static func == (lhs: IncomingCallRequest, rhs: IncomingCallRequest) -> Bool {
        lhs.tag == rhs.tag &&
            lhs.caller == rhs.caller &&
            lhs.hasVideo == rhs.hasVideo &&
            lhs.url == rhs.url &&
            lhs.timeout == rhs.timeout &&
            lhs.webhookID == rhs.webhookID &&
            NSDictionary(dictionary: lhs.actionData).isEqual(to: rhs.actionData)
    }
}
