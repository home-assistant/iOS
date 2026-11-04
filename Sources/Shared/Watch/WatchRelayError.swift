import Foundation

/// A relayed request that the iPhone put on the network and that failed there.
///
/// Distinct from the relay simply being unavailable: those cases return no result at all and the
/// watch performs the request itself. This one is the phone's answer, so it is surfaced to the
/// caller rather than retried.
public struct WatchRelayError: LocalizedError, Equatable {
    /// The phone's description of what went wrong, carried across for the logs.
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public var errorDescription: String? {
        reason
    }
}
