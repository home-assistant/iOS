import CryptoKit
import Foundation

/// A Noise `CipherState`: an AEAD key plus the per-direction counter that also provides the
/// protocol's replay protection — a repeated or reordered frame fails to decrypt.
///
/// This client only ever announces the `25519_ChaChaPoly_SHA256` suite, which the specification
/// requires every server to support, so no cipher negotiation is needed.
struct SendspinNoiseCipherState {
    static let tagLength = 16

    private let key: SymmetricKey?
    private var nonce: UInt64 = 0

    var hasKey: Bool { key != nil }

    init(key: SymmetricKey? = nil) {
        self.key = key
    }

    mutating func encrypt(plaintext: Data, associatedData: Data) throws -> Data {
        guard let key else { return plaintext }
        let sealed = try ChaChaPoly.seal(
            plaintext,
            using: key,
            nonce: Self.nonce(counter: nonce),
            authenticating: associatedData
        )
        nonce += 1
        return sealed.ciphertext + sealed.tag
    }

    mutating func decrypt(ciphertext: Data, associatedData: Data) throws -> Data {
        guard let key else { return ciphertext }
        guard ciphertext.count >= Self.tagLength else { throw SendspinNoiseError.messageTooShort }
        let box = try ChaChaPoly.SealedBox(
            nonce: Self.nonce(counter: nonce),
            ciphertext: ciphertext.prefix(ciphertext.count - Self.tagLength),
            tag: ciphertext.suffix(Self.tagLength)
        )
        guard let plaintext = try? ChaChaPoly.open(box, using: key, authenticating: associatedData) else {
            throw SendspinNoiseError.decryptionFailed
        }
        nonce += 1
        return plaintext
    }

    /// Noise's ChaChaPoly nonce: four zero bytes followed by the little-endian counter.
    private static func nonce(counter: UInt64) throws -> ChaChaPoly.Nonce {
        var bytes = Data(repeating: 0, count: 4)
        withUnsafeBytes(of: counter.littleEndian) { bytes.append(contentsOf: $0) }
        return try ChaChaPoly.Nonce(data: bytes)
    }
}
