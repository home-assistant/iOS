import Foundation

public enum HAAPIError: Error, Sendable, Equatable {
    /// The socket or network layer failed; the connection will reconnect per its policy.
    case transport(description: String)
    /// The server rejected the access token (`auth_invalid`). Fatal: the connection stops and
    /// must be re-`connect()`-ed after the credential problem is fixed.
    case authenticationFailed(message: String?)
    /// The server answered a command with `success: false`.
    case server(code: String, message: String)
    /// The server's reply did not match the request's `Response` type.
    case decoding(command: String, description: String)
    /// The request or connection was cancelled (`disconnect()` or task cancellation).
    case cancelled
    /// The URL or token provider threw before a connection could be attempted.
    case invalidConfiguration(description: String)
}
