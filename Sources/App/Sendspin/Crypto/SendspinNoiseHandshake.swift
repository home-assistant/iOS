import CryptoKit
import Foundation

/// The client half of Sendspin's `KKpsk2` Noise handshake.
///
/// The server is always the Noise initiator regardless of who opened the WebSocket, so this type
/// only ever reads message 1 and writes message 2. Both static keys are known up front (they are
/// the `server_id` and `client_id`), and the PSK the server named in message 1 is mixed in at the
/// end of message 2 — which is why message 1's payload can be read before the PSK is chosen.
struct SendspinNoiseHandshake {
    /// The credential message 1 references, so the caller can look up a matching pairing record
    /// before message 2 mixes the key in.
    struct PskReference: Equatable {
        /// One of `lt` (long-term), `pr` (pairing) or `sn` (Sentinel).
        let category: String
        let identifier: String
    }

    static let protocolName = "Noise_KKpsk2_25519_ChaChaPoly_SHA256"

    private var symmetric: SendspinNoiseSymmetricState
    private let identity: SendspinIdentity
    private let serverStaticKey: Curve25519.KeyAgreement.PublicKey
    private var remoteEphemeral: Curve25519.KeyAgreement.PublicKey?

    var handshakeHash: Data { symmetric.handshakeHash }

    init(identity: SendspinIdentity, serverPublicKey: Data, prologue: Data) throws {
        guard let serverKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: serverPublicKey) else {
            throw SendspinNoiseError.invalidPublicKey
        }
        self.identity = identity
        serverStaticKey = serverKey
        symmetric = SendspinNoiseSymmetricState(protocolName: Self.protocolName)
        symmetric.mixHash(prologue)
        // Pre-messages, initiator first: the server's static key, then ours.
        symmetric.mixHash(serverPublicKey)
        symmetric.mixHash(identity.publicKeyBytes)
    }

    /// Reads `-> e, es, ss` and returns the PSK the server's payload references.
    mutating func readMessage1(_ message: Data) throws -> PskReference {
        guard message.count >= 32 else { throw SendspinNoiseError.messageTooShort }
        let ephemeralBytes = Data(message.prefix(32))
        guard let ephemeral = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralBytes) else {
            throw SendspinNoiseError.invalidPublicKey
        }
        remoteEphemeral = ephemeral
        symmetric.mixHash(ephemeralBytes)
        let ephemeralAgreement = try Self.agree(identity.privateKey, ephemeral)
        symmetric.mixKey(ephemeralAgreement)
        let staticAgreement = try Self.agree(identity.privateKey, serverStaticKey)
        symmetric.mixKey(staticAgreement)

        let payload = try symmetric.decryptAndHash(Data(message.dropFirst(32)))
        let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any]
        guard
            let identifier = object?["psk_id"] as? String,
            let category = object?["psk_category"] as? String
        else {
            throw SendspinNoiseError.malformedHandshakePayload
        }
        return PskReference(category: category, identifier: identifier)
    }

    /// Writes `<- e, ee, se, psk` with the specification's literal `{}` payload.
    mutating func writeMessage2(psk: SendspinPsk) throws -> Data {
        guard let remoteEphemeral else { throw SendspinNoiseError.messageTooShort }
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let ephemeralBytes = ephemeral.publicKey.rawRepresentation
        symmetric.mixHash(ephemeralBytes)
        let ephemeralAgreement = try Self.agree(ephemeral, remoteEphemeral)
        symmetric.mixKey(ephemeralAgreement)
        let staticAgreement = try Self.agree(ephemeral, serverStaticKey)
        symmetric.mixKey(staticAgreement)
        symmetric.mixKeyAndHash(psk.bytes)
        let payload = try symmetric.encryptAndHash(Data("{}".utf8))
        return ephemeralBytes + payload
    }

    /// The transport ciphers, ready for use once both handshake messages have been exchanged.
    func makeSession() -> SendspinNoiseSession {
        let ciphers = symmetric.split()
        return SendspinNoiseSession(
            sending: ciphers.responderSending,
            receiving: ciphers.initiatorSending,
            handshakeHash: symmetric.handshakeHash
        )
    }

    private static func agree(
        _ privateKey: Curve25519.KeyAgreement.PrivateKey,
        _ publicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> Data {
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        return secret.withUnsafeBytes { Data($0) }
    }
}
