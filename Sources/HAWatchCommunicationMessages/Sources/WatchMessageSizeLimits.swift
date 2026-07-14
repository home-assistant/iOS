import Foundation

/// Payload ceilings WatchConnectivity enforces at runtime (WCErrorCodePayloadTooLarge). Apple
/// doesn't document the exact numbers; these are the empirically stable values, used to warn (and
/// where possible fall back) before WCSession rejects a transfer.
public enum WatchMessageSizeLimits {
    /// `sendMessage` payload ceiling (~65.5 KB), applying to interactive messages and their replies.
    public static let interactiveMessage = 65_536
    /// `updateApplicationContext` / `transferUserInfo` payload ceiling (~262.1 KB).
    /// `transferFile` has no such cap.
    public static let applicationContext = 262_144
}
