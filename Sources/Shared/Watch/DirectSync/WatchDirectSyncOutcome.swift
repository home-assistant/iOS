#if os(watchOS)
import Foundation

/// The result of one server's direct websocket sync run.
public struct WatchDirectSyncOutcome: Sendable, Equatable {
    /// Skip reason for a server whose URL can't be resolved on the watch (e.g. internal-only
    /// `http` with a "most secure" access level, unverifiable off the home network). A constant so
    /// UI can match it and offer the internal-URL consent prompt.
    public static let noReachableURLReason = "no reachable URL"

    public enum Status: Sendable, Equatable {
        case success
        /// The server was not attempted (throttled, or no URL is reachable from the watch).
        /// Existing rows for it are left untouched.
        case skipped(reason: String)
        case failed(String)
    }

    public let serverId: String
    public let status: Status

    public init(serverId: String, status: Status) {
        self.serverId = serverId
        self.status = status
    }
}
#endif
