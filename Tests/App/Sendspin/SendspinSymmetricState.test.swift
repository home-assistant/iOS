import CryptoKit
import Foundation
@testable import HomeAssistant
import Testing

struct SendspinSymmetricStateTests {
    /// The protocol name is longer than the hash output, so Noise starts from its digest rather
    /// than the padded name.
    @Test func seedsTheHandshakeHashFromTheProtocolName() {
        let state = SendspinNoiseSymmetricState(protocolName: SendspinNoiseHandshake.protocolName)
        let expected = Data(SHA256.hash(data: Data(SendspinNoiseHandshake.protocolName.utf8)))
        #expect(state.handshakeHash == expected)
        #expect(state.chainingKey == expected)
    }

    @Test func padsAShortProtocolName() {
        let state = SendspinNoiseSymmetricState(protocolName: "Noise_XX")
        #expect(state.handshakeHash.count == 32)
        #expect(state.handshakeHash.prefix(8) == Data("Noise_XX".utf8))
        #expect(state.handshakeHash.suffix(24) == Data(repeating: 0, count: 24))
    }

    /// Two states fed the same inputs must end up with the same keys — the property the whole
    /// handshake rests on.
    @Test func derivesMatchingKeysFromMatchingInputs() throws {
        var first = SendspinNoiseSymmetricState(protocolName: SendspinNoiseHandshake.protocolName)
        var second = SendspinNoiseSymmetricState(protocolName: SendspinNoiseHandshake.protocolName)
        first.mixHash(Data("prologue".utf8))
        second.mixHash(Data("prologue".utf8))
        first.mixKey(Data(repeating: 7, count: 32))
        second.mixKey(Data(repeating: 7, count: 32))
        first.mixKeyAndHash(Data(repeating: 9, count: 32))
        second.mixKeyAndHash(Data(repeating: 9, count: 32))
        #expect(first.handshakeHash == second.handshakeHash)

        let ciphertext = try first.encryptAndHash(Data("{}".utf8))
        #expect(try second.decryptAndHash(ciphertext) == Data("{}".utf8))
        #expect(first.handshakeHash == second.handshakeHash)
    }
}
