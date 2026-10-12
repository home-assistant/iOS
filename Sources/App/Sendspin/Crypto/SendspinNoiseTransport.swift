import Foundation

/// The established Noise transport: one cipher per direction, each counting the messages it has
/// processed so a replayed or reordered one fails to decrypt.
struct SendspinNoiseTransport {
    /// The handshake hash `h`, which a re-handshake uses as its prologue.
    let handshakeHash: Data

    private var sending: SendspinNoiseCipherState
    private var receiving: SendspinNoiseCipherState

    init(sending: SendspinNoiseCipherState, receiving: SendspinNoiseCipherState, handshakeHash: Data) {
        self.sending = sending
        self.receiving = receiving
        self.handshakeHash = handshakeHash
    }

    mutating func encrypt(_ plaintext: Data) throws -> Data {
        try sending.encrypt(plaintext: plaintext, associatedData: Data())
    }

    mutating func decrypt(_ ciphertext: Data) throws -> Data {
        try receiving.decrypt(ciphertext: ciphertext, associatedData: Data())
    }
}
