import Foundation

/// Raised when a server has no usable active URL for a request. Lives in HANetworking because both
/// `ConnectionInfo` (which throws it) and `AuthenticationAPI` (which will move here) use it.
public enum ServerConnectionError: Error {
    case noActiveURL(_ serverName: String)
}
