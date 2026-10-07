import Foundation

/// Stable machine-readable reason sent in a `magicItemRowPressedResponse` alongside `fired: false`,
/// so the watch can present a localized message while the technical detail (the `error` field) goes
/// to client events. Raw values cross the WatchConnectivity wire — don't repurpose them.
public enum MagicItemExecutionFailureCode: String {
    /// The press was too old by the time it reached the phone.
    case staleRequest
    /// The message was missing/carrying an invalid item type or id.
    case invalidItem
    /// The item type has no executable action (folder, Assist, unsupported).
    case notExecutable
    /// The server referenced by the item isn't configured on the phone.
    case serverNotFound
    /// The phone has no usable connection for the server.
    case noConnection
    /// The service call ran and the server (or transport) reported an error — the `error` detail is
    /// the underlying message and is meaningful to show the user.
    case serviceCallFailed
}
