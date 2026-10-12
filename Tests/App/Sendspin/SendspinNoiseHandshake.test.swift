import CryptoKit
import Foundation
@testable import HomeAssistant
import Testing

/// Reference values produced with the `noiseprotocol` library that `aiosendspin` builds on, from
/// fixed keys, so the responder here is checked against an independent implementation.
struct SendspinNoiseHandshakeTests {
    private enum Vector {
        static let clientStatic = "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
        static let serverStatic = "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
        static let clientEphemeral = "6162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f80"
        static let clientID = "B6N8vBQgk8i3VdwbEOhstCY3StFqqFPtC9_AsrhtHHw"
        static let serverID = "WGmv9FBUlzLLqu1eXfmzCm2jHLDldCutWtShp2jxpns"
        static let clientInit =
            "{\"type\":\"client/init\",\"payload\":{\"client_id\":\"B6N8vBQgk8i3VdwbEOhstCY3StFqqFPtC9_AsrhtHHw\",\"version\":1,\"suite\":\"25519_ChaChaPoly_SHA256\"}}"
        static let serverInit =
            "{\"type\":\"server/init\",\"payload\":{\"server_id\":\"WGmv9FBUlzLLqu1eXfmzCm2jHLDldCutWtShp2jxpns\",\"version\":1}}"
        static let message1 =
            "64b101b1d0be5a8704bd078f9895001fc03e8e9f9522f188dd128d9846d48466750ec9242eae42c0bcaf67f8d95e29f8971d8aa0489153383661c3e9472fdee2901071105c192b0a8215244bce2d2f53d352c14a7686b1c308d5a6267699d9a599ba841fe212f35c8cba83d0f841db1f49dd12a2a23a7459d581be6f"
        static let message2 =
            "244fe3b963e899dd295baffce248d3530f3a9a7479ba063002680ebfe7adad4909c403a3c7e4e1e4e30421d3ae3b023e1f29"
        static let handshakeHash = "c530e3f7c2c2d16b62c8efee93e0409d55bd9f48d71d598a9909c2c4fb9e74d4"
        static let serverToClient =
            "6c570128d24b96363f21080660db2efae54f60e4b3946e3375b7fa93b8cb0da95f99e08ff8e630e2815b41829c85fa0af09decb0151c5b62ed4c6f39fc29d43acdc4500cbb8889cef22e83e646"
        static let clientToServerSecond =
            "841d5ca241f28b00758abe89ab41aedb6bfe96f4f1dbda3a4331fe6751bf0351a37793f4742aa91ce78941d0496207a0009252f8533cd362e697b1de5748824fc8dd1c8471d40a8734c8"
        static let longTermPsk = "c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7"
        static let longTermPskID = "XXghF9SONiiTmUW3UVkl6IPjk4jjVFeQz82NrN06usE"
        static let rehandshakeClientEphemeral = "a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0"
        static let rehandshakeMessage1 =
            "883186b800b41d5cf0429695da9b3cc4f328ebcd184a6e482fa578c103f06c7702686adb688e39a1514832745614e9f5e3fdeb947d8f5cd3773451ce3715309ddd5715dae25d4891e3171daa2d26d79b71dcf9f499af9d83a016d96fb59f53b827cb9ccf7f327a1631f07f54f4081715e4da05b4e539de1a6825c3f8"
        static let rehandshakeMessage2 =
            "ad438bfae31f6c093d61d4339255ea798092c9fadd07b97827f4b0ae9dee7c1c103b9a1e141309b30c994a27ee89e6d06a9f"
        static let rehandshakeHash = "6c8fdb135c405a1016c51403bce9856056793563da896228f4c71b5d50a821ac"
        static let rehandshakeServerToClient =
            "f4306b7910b2bf2784bdbfa9cf117fedee8bbd6e5ea4843d949f0bef05b6599c07358a07c2e51b14b1e81502e619e708e9499ec307ec99d61fe6e34c29ca94ae01a3c1bf7f48bbbb588f2c4ded"
    }

    private static func bytes(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index ..< next], radix: 16)!)
            index = next
        }
        return data
    }

    private static func key(_ hex: String) throws -> Curve25519.KeyAgreement.PrivateKey {
        try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: bytes(hex))
    }

    private var identity: SendspinIdentity {
        get throws { try SendspinIdentity(privateKey: Self.key(Vector.clientStatic)) }
    }

    private var serverPublicKey: Data {
        get throws { try Self.key(Vector.serverStatic).publicKey.rawRepresentation }
    }

    @Test func identitiesEncodeAsBase64URL() throws {
        let identity = try identity
        let serverPublicKey = try serverPublicKey
        #expect(identity.clientID == Vector.clientID)
        #expect(SendspinBase64URL.encode(serverPublicKey) == Vector.serverID)
        #expect(SendspinIdentity(privateKeyBytes: identity.privateKeyBytes)?.clientID == Vector.clientID)
        #expect(SendspinIdentity(privateKeyBytes: Data([1, 2, 3])) == nil)
    }

    @Test func respondsLikeTheReferenceImplementation() throws {
        var handshake = try SendspinNoiseHandshake(
            identity: identity,
            serverPublicKey: serverPublicKey,
            prologue: Data(Vector.clientInit.utf8) + Data(Vector.serverInit.utf8),
            ephemeral: Self.key(Vector.clientEphemeral)
        )

        let payload = try handshake.readMessage1(Self.bytes(Vector.message1))
        let reference = try JSONDecoder().decode(SendspinPskReference.self, from: payload)
        #expect(reference == SendspinPskReference(pskID: SendspinPsk.sentinel.identifier, category: .sentinel))

        let result = try handshake.writeMessage2(psk: .sentinel)
        var transport = result.transport
        #expect(result.message == Self.bytes(Vector.message2))
        #expect(transport.handshakeHash == Self.bytes(Vector.handshakeHash))

        let hello = try transport.decrypt(Self.bytes(Vector.serverToClient))
        #expect(hello.first == 0)
        #expect(String(decoding: hello.dropFirst(), as: UTF8.self).contains("Music Assistant"))

        let time = Data([0]) + Data(#"{"type":"client/time","payload":{"client_transmitted":1}}"#.utf8)
        _ = try transport.encrypt(time)
        let matchesReference = try transport.encrypt(time) == Self.bytes(Vector.clientToServerSecond)
        #expect(matchesReference)
    }

    /// A re-handshake uses the previous handshake hash as its prologue and a long-term PSK.
    @Test func rehandshakesLikeTheReferenceImplementation() throws {
        var handshake = try SendspinNoiseHandshake(
            identity: identity,
            serverPublicKey: serverPublicKey,
            prologue: Self.bytes(Vector.handshakeHash),
            ephemeral: Self.key(Vector.rehandshakeClientEphemeral)
        )
        let payload = try handshake.readMessage1(Self.bytes(Vector.rehandshakeMessage1))
        let reference = try JSONDecoder().decode(SendspinPskReference.self, from: payload)
        let psk = try #require(SendspinPsk(bytes: Self.bytes(Vector.longTermPsk)))
        #expect(reference == SendspinPskReference(pskID: Vector.longTermPskID, category: .longTerm))
        #expect(psk.identifier == Vector.longTermPskID)

        let result = try handshake.writeMessage2(psk: psk)
        var transport = result.transport
        #expect(result.message == Self.bytes(Vector.rehandshakeMessage2))
        #expect(transport.handshakeHash == Self.bytes(Vector.rehandshakeHash))
        let isJSON = try transport.decrypt(Self.bytes(Vector.rehandshakeServerToClient)).first == 0
        #expect(isJSON)
    }

    @Test func aWrongPrologueFailsToAuthenticate() throws {
        var handshake = try SendspinNoiseHandshake(
            identity: identity,
            serverPublicKey: serverPublicKey,
            prologue: Data("tampered".utf8)
        )
        #expect(throws: SendspinNoiseError.decryptionFailed) {
            try handshake.readMessage1(Self.bytes(Vector.message1))
        }
    }

    @Test func malformedMessagesAreRejected() throws {
        #expect(throws: SendspinNoiseError.invalidPublicKey) {
            try SendspinNoiseHandshake(identity: identity, serverPublicKey: Data([1]), prologue: Data())
        }
        var handshake = try SendspinNoiseHandshake(
            identity: identity,
            serverPublicKey: serverPublicKey,
            prologue: Data()
        )
        #expect(throws: SendspinNoiseError.handshakeOutOfOrder) {
            try handshake.writeMessage2(psk: .sentinel)
        }
        #expect(throws: SendspinNoiseError.messageTooShort) {
            try handshake.readMessage1(Data([1, 2, 3]))
        }
    }

    @Test func aReplayedTransportMessageFailsToDecrypt() throws {
        var handshake = try SendspinNoiseHandshake(
            identity: identity,
            serverPublicKey: serverPublicKey,
            prologue: Data(Vector.clientInit.utf8) + Data(Vector.serverInit.utf8),
            ephemeral: Self.key(Vector.clientEphemeral)
        )
        _ = try handshake.readMessage1(Self.bytes(Vector.message1))
        var transport = try handshake.writeMessage2(psk: .sentinel).transport
        let message = Self.bytes(Vector.serverToClient)
        _ = try transport.decrypt(message)
        #expect(throws: SendspinNoiseError.decryptionFailed) {
            try transport.decrypt(message)
        }
        #expect(throws: SendspinNoiseError.messageTooShort) {
            try transport.decrypt(Data([1]))
        }
    }
}
