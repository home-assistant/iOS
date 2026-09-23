import Foundation

/// Payload of an `httpRequest` message (watch → phone): one HTTP request the watch wants the phone
/// to put on the network for it, so it leaves from the phone's vantage point instead of the
/// watch's. Key names cross the wire — never rename them.
///
/// `url` is what the watch resolved from its own `ConnectionInfo`, which on the watch can only ever
/// pick a remote URL — it has no network information of its own to evaluate the internal one
/// against. The phone re-bases it against its own active URL before dialing (see
/// `WatchRelayURLRebase`), which is the whole point of relaying rather than just proxying bytes.
public struct WatchHTTPRequestPayload {
    /// Which server the request belongs to, so the phone can find it and re-evaluate the base URL.
    public let serverId: String
    /// The absolute URL the watch resolved, re-based by the phone when it can be.
    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let body: Data?
    /// How long the phone should allow the request itself to take, mirroring the bound the watch
    /// would have applied. Kept separate from the reply timeout so a caller with a tight budget
    /// (complication refresh, entity polling) keeps it across the relay.
    public let timeout: TimeInterval

    public init(
        serverId: String,
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval
    ) {
        self.serverId = serverId
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }

    public init?(content: [String: Any]) {
        guard let serverId = content["serverId"] as? String,
              let urlString = content["url"] as? String,
              let url = URL(string: urlString),
              let method = content["method"] as? String,
              let timeout = content["timeout"] as? TimeInterval else {
            return nil
        }
        self.serverId = serverId
        self.url = url
        self.method = method
        self.headers = content["headers"] as? [String: String] ?? [:]
        self.body = content["body"] as? Data
        self.timeout = timeout
    }

    /// Whether repeating this request is harmless. Decides whether the watch may perform it itself
    /// after a failure the phone hit *after* reaching the server: a second GET costs a round trip,
    /// a second `POST /api/services/light/toggle` turns the light back off.
    public var isIdempotent: Bool {
        ["GET", "HEAD", "OPTIONS"].contains(method.uppercased())
    }

    /// `URL` isn't property-list serializable, which is what WCSession encodes to, so it crosses as
    /// its string form.
    public var content: [String: Any] {
        var content: [String: Any] = [
            "serverId": serverId,
            "url": url.absoluteString,
            "method": method,
            "headers": headers,
            "timeout": timeout,
        ]
        if let body {
            content["body"] = body
        }
        return content
    }
}
