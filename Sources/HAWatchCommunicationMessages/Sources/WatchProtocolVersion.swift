import Foundation

/// Version of the watch↔iPhone message protocol, stamped into every message envelope so a
/// receiver can branch on the sender's capabilities instead of relying purely on defensive
/// decoding.
///
/// History:
/// - (absent) — builds that predate versioning; treat as the lowest capability.
/// - 1 — first versioned protocol (2026-07).
/// - 2 — the phone performs HTTP requests relayed from the watch (`httpRequest`).
/// - 3 — the watch speaks Assist answers itself (`assistOnDeviceTTS`).
/// - 4 — the watch reads the Assist responses the phone hands back in its `pong` (`PongPayload`).
public enum WatchProtocolVersion {
    public static let current = 4

    /// The version the phone must be at before the watch relays an HTTP request to it. An older
    /// phone drops the unknown identifier without replying, so relaying to one would cost a full
    /// reply timeout per request before falling back.
    public static let httpRelay = 2

    /// The version the watch must be at before the phone skips server speech in favour of
    /// `assistOnDeviceTTS`. An older watch drops the unknown identifier, so it would stay silent.
    public static let assistOnDeviceTTS = 3

    /// The version the watch must be at before the phone keeps an Assist response it could not push
    /// for the watch's next `pong`. An older watch ignores what a `pong` carries.
    public static let assistResponsesInPong = 4
}
