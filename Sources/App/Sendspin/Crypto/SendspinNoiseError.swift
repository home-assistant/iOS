import Foundation

/// Every Noise-layer failure closes the WebSocket without telling the peer why, so these cases
/// exist for the log rather than for the wire.
enum SendspinNoiseError: Error, Equatable {
    case invalidPublicKey
    case messageTooShort
    case decryptionFailed
    case malformedHandshakePayload
    case handshakeOutOfOrder
}
