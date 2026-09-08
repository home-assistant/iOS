import Foundation

/// Everything the extension needs to issue one `mobile_app` webhook command, and nothing more.
///
/// Kept out of `RemoteMediaSessionAttributes` on purpose: attributes travel through Apple's
/// RemoteMedia infrastructure, while this carries the webhook secret and so lives in the shared
/// Keychain instead. See `RemoteMediaTransportStore`.
public struct RemoteMediaTransportContext: Codable, Equatable, Sendable {
    /// The followed player. A command whose selection no longer matches is refused, so a stale
    /// system callback cannot control a player the user has since stopped following.
    public let selection: RemoteMediaSelection
    /// Webhook endpoints in the order they should be tried: cloudhook, external, internal.
    public let webhookURLs: [URL]
    /// The secretbox key, already derived for the server's version by the host app. `nil` when the
    /// registration legitimately has no secret, in which case the payload is sent in plaintext.
    public let secret: [UInt8]?

    public init(selection: RemoteMediaSelection, webhookURLs: [URL], secret: [UInt8]?) {
        self.selection = selection
        self.webhookURLs = webhookURLs
        self.secret = secret
    }
}
