import CryptoKit
import Foundation

/// The client side of Sendspin's `Noise_KKpsk2_25519_ChaChaPoly_SHA256` handshake.
///
/// The server is always the Noise initiator, whoever opened the WebSocket, so this only ever reads
/// message 1 (`-> e, es, ss`) and writes message 2 (`<- e, ee, se, psk`). Both static keys are
/// known up front, and the PSK is mixed in at the end of message 2, which is why message 1's
/// payload, naming the PSK, can be read before one is chosen.
struct SendspinNoiseHandshake {
    static let protocolName = "Noise_KKpsk2_25519_ChaChaPoly_SHA256"

    private var symmetric: SendspinNoiseSymmetricState
    private let identity: SendspinIdentity
    private let serverStaticKey: Curve25519.KeyAgreement.PublicKey
    private let serverStaticKeyBytes: Data
    private let ephemeral: Curve25519.KeyAgreement.PrivateKey
    private var remoteEphemeral: Curve25519.KeyAgreement.PublicKey?

    /// - Parameter ephemeral: Only ever passed by tests, which need a fixed key to reproduce a
    ///   reference handshake; production always draws a fresh one.
    init(
        identity: SendspinIdentity,
        serverPublicKey: Data,
        prologue: Data,
        ephemeral: Curve25519.KeyAgreement.PrivateKey = Curve25519.KeyAgreement.PrivateKey()
    ) throws {
        guard let serverKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: serverPublicKey) else {
            throw SendspinNoiseError.invalidPublicKey
        }
        self.identity = identity
        self.serverStaticKey = serverKey
        self.serverStaticKeyBytes = serverPublicKey
        self.ephemeral = ephemeral
        self.symmetric = SendspinNoiseSymmetricState(protocolName: Self.protocolName)
        symmetric.mixHash(prologue)
        // Pre-messages, initiator first: the server's static key, then this device's.
        symmetric.mixHash(serverPublicKey)
        symmetric.mixHash(identity.publicKeyBytes)
    }

    /// Reads message 1 and returns its decrypted payload, which names the PSK to use.
    mutating func readMessage1(_ message: Data) throws -> Data {
        guard remoteEphemeral == nil else { throw SendspinNoiseError.handshakeOutOfOrder }
        guard message.count >= 32 else { throw SendspinNoiseError.messageTooShort }
        let ephemeralBytes = Data(message.prefix(32))
        guard let remote = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralBytes) else {
            throw SendspinNoiseError.invalidPublicKey
        }
        remoteEphemeral = remote
        symmetric.mixHash(ephemeralBytes)
        // In a PSK handshake every `e` token is also mixed into the key, not only the hash.
        symmetric.mixKey(ephemeralBytes)
        try symmetric.mixKey(Self.agree(identity.privateKey, remote))
        try symmetric.mixKey(Self.agree(identity.privateKey, serverStaticKey))
        return try symmetric.decryptAndHash(Data(message.dropFirst(32)))
    }

    /// Writes message 2 carrying the specification's literal `{}` payload and returns it with the
    /// transport that is ready once the server has read it.
    mutating func writeMessage2(psk: SendspinPsk) throws -> (message: Data, transport: SendspinNoiseTransport) {
        guard let remoteEphemeral else { throw SendspinNoiseError.handshakeOutOfOrder }
        let ephemeralBytes = ephemeral.publicKey.rawRepresentation
        symmetric.mixHash(ephemeralBytes)
        symmetric.mixKey(ephemeralBytes)
        try symmetric.mixKey(Self.agree(ephemeral, remoteEphemeral))
        try symmetric.mixKey(Self.agree(ephemeral, serverStaticKey))
        symmetric.mixKeyAndHash(psk.bytes)
        let payload = try symmetric.encryptAndHash(Data("{}".utf8))

        let ciphers = symmetric.split()
        let transport = SendspinNoiseTransport(
            sending: ciphers.responder,
            receiving: ciphers.initiator,
            handshakeHash: symmetric.handshakeHash
        )
        return (ephemeralBytes + payload, transport)
    }

    private static func agree(
        _ privateKey: Curve25519.KeyAgreement.PrivateKey,
        _ publicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> Data {
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        return secret.withUnsafeBytes { Data($0) }
    }
}
