import CryptoKit
import Foundation
@testable import HomeAssistant
import Testing

/// Plays a Sendspin server against a session: the Noise initiator side of `KKpsk2`, written from
/// the specification independently of the session's responder, and the encrypted channel after.
struct SendspinTestServer {
    struct NotConnected: Error {}

    let connection: SendspinTestLink
    let staticKey = Curve25519.KeyAgreement.PrivateKey()
    private(set) var clientKey: Curve25519.KeyAgreement.PublicKey?
    private(set) var transport: SendspinNoiseTransport?
    /// Messages read while waiting for a different type, handed out first next time.
    private var pending: [(type: String, body: Data)] = []

    init(connection: SendspinTestLink) {
        self.connection = connection
    }

    var serverID: String {
        SendspinBase64URL.encode(staticKey.publicKey.rawRepresentation)
    }

    // MARK: - Handshake

    /// Runs the cleartext handshake. `reference` is what message 1 names; `psk` is what this side
    /// actually mixes in, which differ when testing the Sentinel fallback.
    mutating func handshake(reference: SendspinPskReference, psk: SendspinPsk) async throws {
        let clientInit = try await connection.nextSent()
        #expect(clientInit.kind == .text)
        let initPayload = try JSONDecoder().decode(SendspinEnvelope<SendspinClientInit>.self, from: clientInit.data)
        #expect(initPayload.type == "client/init")
        #expect(initPayload.payload.version == 1)
        #expect(initPayload.payload.suite == "25519_ChaChaPoly_SHA256")
        let clientKeyBytes = try #require(SendspinBase64URL.decode(initPayload.payload.clientID))
        clientKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: clientKeyBytes)

        let serverInit = try SendspinClientMessage.encode(
            type: "server/init",
            payload: SendspinServerInit(serverID: serverID, version: 1)
        )
        connection.deliver(.text, serverInit)

        let (message1, finish) = try startHandshake(
            prologue: clientInit.data + serverInit,
            reference: reference,
            psk: psk
        )
        let encodedMessage1 = try SendspinClientMessage.handshake(message1).encoded()
        connection.deliver(.text, encodedMessage1)

        let reply = try await connection.nextSent()
        #expect(reply.kind == .text)
        let message2 = try JSONDecoder().decode(SendspinEnvelope<SendspinNoiseHandshakeMessage>.self, from: reply.data)
        transport = try finish(message2.payload)
    }

    /// Runs a re-handshake inside the encrypted channel.
    mutating func rehandshake(reference: SendspinPskReference, psk: SendspinPsk) async throws {
        let prologue = try #require(transport?.handshakeHash)
        let (message1, finish) = try startHandshake(prologue: prologue, reference: reference, psk: psk)
        try send(type: "noise/handshake", payload: message1)
        let message2 = try await receive(SendspinNoiseHandshakeMessage.self, type: "noise/handshake")
        transport = try finish(message2)
    }

    private func startHandshake(
        prologue: Data,
        reference: SendspinPskReference,
        psk: SendspinPsk
    ) throws -> (SendspinNoiseHandshakeMessage, (SendspinNoiseHandshakeMessage) throws -> SendspinNoiseTransport) {
        let clientKey = try #require(clientKey)
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let staticKey = staticKey
        var symmetric = SendspinNoiseSymmetricState(protocolName: SendspinNoiseHandshake.protocolName)
        symmetric.mixHash(prologue)
        symmetric.mixHash(staticKey.publicKey.rawRepresentation)
        symmetric.mixHash(clientKey.rawRepresentation)

        // -> e, es, ss
        let ephemeralBytes = ephemeral.publicKey.rawRepresentation
        symmetric.mixHash(ephemeralBytes)
        symmetric.mixKey(ephemeralBytes)
        try symmetric.mixKey(Self.agree(ephemeral, clientKey))
        try symmetric.mixKey(Self.agree(staticKey, clientKey))
        let payload = try symmetric.encryptAndHash(JSONEncoder().encode(reference))
        let message1 = SendspinNoiseHandshakeMessage(data: SendspinBase64URL.encode(ephemeralBytes + payload))

        let finish: (SendspinNoiseHandshakeMessage) throws -> SendspinNoiseTransport = { message in
            var symmetric = symmetric
            let bytes = try #require(SendspinBase64URL.decode(message.data))
            // <- e, ee, se, psk
            let remoteBytes = Data(bytes.prefix(32))
            let remote = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteBytes)
            symmetric.mixHash(remoteBytes)
            symmetric.mixKey(remoteBytes)
            try symmetric.mixKey(Self.agree(ephemeral, remote))
            try symmetric.mixKey(Self.agree(staticKey, remote))
            symmetric.mixKeyAndHash(psk.bytes)
            let body = try symmetric.decryptAndHash(Data(bytes.dropFirst(32)))
            #expect(body == Data("{}".utf8))
            let ciphers = symmetric.split()
            return SendspinNoiseTransport(
                sending: ciphers.initiator,
                receiving: ciphers.responder,
                handshakeHash: symmetric.handshakeHash
            )
        }
        return (message1, finish)
    }

    private static func agree(
        _ privateKey: Curve25519.KeyAgreement.PrivateKey,
        _ publicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> Data {
        try privateKey.sharedSecretFromKeyAgreement(with: publicKey).withUnsafeBytes { Data($0) }
    }

    // MARK: - Encrypted channel

    mutating func send(type: String, payload: some Codable) throws {
        let body = try SendspinClientMessage.encode(type: type, payload: payload)
        var plaintext = Data([0])
        plaintext.append(body)
        try sendPlaintext(plaintext)
    }

    mutating func sendPlaintext(_ plaintext: Data) throws {
        for piece in SendspinFragmentation.plaintexts(for: plaintext) {
            guard let ciphertext = try transport?.encrypt(piece) else { throw NotConnected() }
            connection.deliver(.binary, ciphertext)
        }
    }

    /// The next message of `type` the session sent, decoded; other messages are kept for later.
    mutating func receive<Payload: Decodable>(_: Payload.Type, type: String) async throws -> Payload {
        if let index = pending.firstIndex(where: { $0.type == type }) {
            return try decode(Payload.self, from: pending.remove(at: index).body)
        }
        while true {
            let frame = try await connection.nextSent()
            #expect(frame.kind == .binary)
            guard let plaintext = try transport?.decrypt(frame.data) else { throw NotConnected() }
            #expect(plaintext.first == 0)
            let body = Data(plaintext.dropFirst())
            let header = try JSONDecoder().decode(SendspinMessageHeader.self, from: body)
            if header.type == type {
                return try decode(Payload.self, from: body)
            }
            pending.append((header.type, body))
        }
    }

    private func decode<Payload: Decodable>(_: Payload.Type, from body: Data) throws -> Payload {
        try JSONDecoder().decode(SendspinTestEnvelope<Payload>.self, from: body).payload
    }
}
