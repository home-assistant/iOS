import Foundation

/// The established Noise transport: one cipher per direction, each carrying the counter that makes
/// a replayed or reordered frame fail to decrypt.
final class SendspinNoiseSession {
    let handshakeHash: Data

    private var sending: SendspinNoiseCipherState
    private var receiving: SendspinNoiseCipherState

    init(sending: SendspinNoiseCipherState, receiving: SendspinNoiseCipherState, handshakeHash: Data) {
        self.sending = sending
        self.receiving = receiving
        self.handshakeHash = handshakeHash
    }

    func encrypt(_ plaintext: Data) throws -> Data {
        try sending.encrypt(plaintext: plaintext, associatedData: Data())
    }

    func decrypt(_ ciphertext: Data) throws -> Data {
        try receiving.decrypt(ciphertext: ciphertext, associatedData: Data())
    }
}
