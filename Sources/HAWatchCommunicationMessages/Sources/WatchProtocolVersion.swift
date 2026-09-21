import Foundation

/// Version of the watch↔iPhone message protocol, stamped into every message envelope so a
/// receiver can branch on the sender's capabilities instead of relying purely on defensive
/// decoding.
///
/// History:
/// - (absent) — builds that predate versioning; treat as the lowest capability.
/// - 1 — first versioned protocol (2026-07).
/// - 2 — the phone performs HTTP requests relayed from the watch (`httpRequest`).
public enum WatchProtocolVersion {
    public static let current = 2

    /// The version the phone must be at before the watch relays an HTTP request to it. An older
    /// phone drops the unknown identifier without replying, so relaying to one would cost a full
    /// reply timeout per request before falling back.
    public static let httpRelay = 2
}
