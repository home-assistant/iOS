import Foundation

/// Whether the current session is backed by a pairing record.
enum SendspinTrustLevel: Equatable {
    /// Authenticated by a long-term PSK a pairing produced.
    case paired
    /// A Sentinel-keyed session. Confidential and replay-protected, but with no assurance about
    /// which peer is on the other end, so an on-path attacker could impersonate the server.
    case unpaired
}
