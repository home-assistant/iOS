import CryptoKit
import Foundation

/// Noise's `SymmetricState`: the chaining key, the running handshake hash every ciphertext is
/// bound to, and the cipher that the pattern's tokens rekey as the handshake progresses.
struct SendspinNoiseSymmetricState {
    private(set) var chainingKey: Data
    private(set) var handshakeHash: Data
    private var cipherState = SendspinNoiseCipherState()

    init(protocolName: String) {
        let name = Data(protocolName.utf8)
        if name.count <= SHA256.byteCount {
            self.handshakeHash = name + Data(repeating: 0, count: SHA256.byteCount - name.count)
        } else {
            self.handshakeHash = Data(SHA256.hash(data: name))
        }
        self.chainingKey = handshakeHash
    }

    mutating func mixHash(_ data: Data) {
        handshakeHash = Data(SHA256.hash(data: handshakeHash + data))
    }

    mutating func mixKey(_ input: Data) {
        let output = Self.hkdf(chainingKey: chainingKey, input: input, outputs: 2)
        chainingKey = output[0]
        cipherState = SendspinNoiseCipherState(key: SymmetricKey(data: output[1]))
    }

    mutating func mixKeyAndHash(_ input: Data) {
        let output = Self.hkdf(chainingKey: chainingKey, input: input, outputs: 3)
        chainingKey = output[0]
        mixHash(output[1])
        cipherState = SendspinNoiseCipherState(key: SymmetricKey(data: output[2]))
    }

    mutating func encryptAndHash(_ plaintext: Data) throws -> Data {
        let ciphertext = try cipherState.encrypt(plaintext: plaintext, associatedData: handshakeHash)
        mixHash(ciphertext)
        return ciphertext
    }

    mutating func decryptAndHash(_ ciphertext: Data) throws -> Data {
        let plaintext = try cipherState.decrypt(ciphertext: ciphertext, associatedData: handshakeHash)
        mixHash(ciphertext)
        return plaintext
    }

    /// The two transport ciphers: the initiator sends with the first, the responder with the
    /// second. On a Sendspin connection the server is always the initiator.
    func split() -> (initiator: SendspinNoiseCipherState, responder: SendspinNoiseCipherState) {
        let output = Self.hkdf(chainingKey: chainingKey, input: Data(), outputs: 2)
        return (
            SendspinNoiseCipherState(key: SymmetricKey(data: output[0])),
            SendspinNoiseCipherState(key: SymmetricKey(data: output[1]))
        )
    }

    /// Noise's own HKDF: chained HMACs, not RFC 5869's counter-based expand.
    private static func hkdf(chainingKey: Data, input: Data, outputs: Int) -> [Data] {
        let temporaryKey = SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(
            for: input,
            using: SymmetricKey(data: chainingKey)
        )))
        var results: [Data] = []
        var previous = Data()
        for index in 1 ... outputs {
            previous = Data(HMAC<SHA256>.authenticationCode(
                for: previous + Data([UInt8(index)]),
                using: temporaryKey
            ))
            results.append(previous)
        }
        return results
    }
}
