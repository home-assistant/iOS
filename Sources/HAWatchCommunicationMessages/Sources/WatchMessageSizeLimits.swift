import Foundation

/// Payload ceilings WatchConnectivity enforces at runtime (WCErrorCodePayloadTooLarge). Apple
/// doesn't document the exact numbers; these are the empirically stable values, used to warn (and
/// where possible fall back) before WCSession rejects a transfer.
public enum WatchMessageSizeLimits {
    /// `sendMessage` payload ceiling (~65.5 KB), applying to interactive messages and their replies.
    public static let interactiveMessage = 65536
    /// `updateApplicationContext` / `transferUserInfo` payload ceiling (~262.1 KB).
    /// `transferFile` has no such cap.
    public static let applicationContext = 262_144
    /// Room to leave for the message envelope (identifier and protocol version) when sizing a
    /// payload against `interactiveMessage`, which bounds the whole encoded message rather than
    /// the content it carries. Generous on purpose — overshooting the real ceiling surfaces on the
    /// counterpart only as a reply that never comes.
    public static let envelopeOverhead = 512
}
