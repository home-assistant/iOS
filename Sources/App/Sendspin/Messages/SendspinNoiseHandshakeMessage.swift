import Foundation

/// `noise/handshake`: one Noise handshake message, base64url encoded.
struct SendspinNoiseHandshakeMessage: Codable, Equatable {
    let data: String
}
