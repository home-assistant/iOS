import Foundation

/// Every Noise-layer failure closes the WebSocket without an application-level error message, so
/// these cases exist to log what happened rather than to be reported to the peer.
enum SendspinNoiseError: Error {
    case invalidPublicKey
    case messageTooShort
    case decryptionFailed
    case malformedHandshakePayload
}
