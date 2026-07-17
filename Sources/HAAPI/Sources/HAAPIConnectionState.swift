public enum HAAPIConnectionState: Sendable, Equatable {
    case disconnected(reason: HAAPIDisconnectReason)
    case connecting
    case authenticating
    case connected(haVersion: String)
}
