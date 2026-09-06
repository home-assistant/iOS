import Foundation

/// Conditions no conformant peer produces. The specification's failure handling closes the socket
/// rather than reporting them, so these values only ever reach the log.
enum SendspinProtocolError: Error {
    case malformedMessage
    case unexpectedMessage(String)
    case unsupportedVersion(Int)
    case invalidServerIdentity
    case fragmentationViolation
}
