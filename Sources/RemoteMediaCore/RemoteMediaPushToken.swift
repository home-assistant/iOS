import CryptoKit
import Foundation

/// The per-session APNs update token Apple hands to a `RemoteMediaSessionRepresentable`.
///
/// This is not the Companion device token: every followed player gets its own token, and it is what
/// a server addresses to push a `nowplaying` update while nothing of ours is running. Apple treats
/// it as a device-scoped identifier, so the full value never reaches a log — `fingerprint` is what
/// diagnostics and de-duplication use.
public struct RemoteMediaPushToken: Equatable, Sendable {
    public let data: Data

    public init(_ data: Data) { self.data = data }

    /// The lowercase hexadecimal form a provider addresses APNs with.
    public var hex: String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    public var byteCount: Int { data.count }

    /// A short, stable, non-reversible label for logs and de-duplication.
    public var fingerprint: String {
        SHA256.hash(data: data).prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}
