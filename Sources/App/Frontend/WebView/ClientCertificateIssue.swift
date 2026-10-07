import Foundation

/// A client certificate (mTLS) problem the web view ran into while loading the frontend, which no retry
/// can fix on its own: the user has to import a certificate.
enum ClientCertificateIssue: Equatable {
    /// The server asked for a client certificate but none is configured for the server on this device.
    case required
    /// The server refused the client certificate configured for the server.
    case rejected
}
