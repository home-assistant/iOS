public enum HAAPIDisconnectReason: Sendable, Equatable {
    /// Never connected yet.
    case initial
    /// `disconnect()` was called.
    case requested
    /// The connection dropped; a reconnect attempt is scheduled per the reconnect policy.
    case waitingToReconnect(attempt: Int, errorDescription: String?)
    /// The server rejected the token; the connection will not retry until `connect()` is called again.
    case authenticationFailed(message: String?)
}
