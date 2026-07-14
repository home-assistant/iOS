import Foundation

/// Version of the watch↔iPhone message protocol, stamped into every message envelope so a
/// receiver can branch on the sender's capabilities instead of relying purely on defensive
/// decoding.
///
/// History:
/// - (absent) — builds that predate versioning; treat as the lowest capability.
/// - 1 — first versioned protocol (2026-07).
public enum WatchProtocolVersion {
    public static let current = 1
}
