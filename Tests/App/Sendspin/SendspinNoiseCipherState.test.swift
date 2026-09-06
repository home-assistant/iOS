import CryptoKit
import Foundation
@testable import HomeAssistant
import Testing

struct SendspinNoiseCipherStateTests {
    private let key = SymmetricKey(size: .bits256)

    @Test func roundTripsThroughMatchingCounters() throws {
        var sender = SendspinNoiseCipherState(key: key)
        var receiver = SendspinNoiseCipherState(key: key)
        for index in 0 ..< 4 {
            let plaintext = Data("message \(index)".utf8)
            let ciphertext = try sender.encrypt(plaintext: plaintext, associatedData: Data())
            #expect(try receiver.decrypt(ciphertext: ciphertext, associatedData: Data()) == plaintext)
        }
    }

    /// The per-direction counter is the protocol's replay protection: the same frame delivered twice
    /// fails to decrypt rather than being accepted again.
    @Test func rejectsAReplayedFrame() throws {
        var sender = SendspinNoiseCipherState(key: key)
        var receiver = SendspinNoiseCipherState(key: key)
        let ciphertext = try sender.encrypt(plaintext: Data("hello".utf8), associatedData: Data())
        _ = try receiver.decrypt(ciphertext: ciphertext, associatedData: Data())
        #expect(throws: SendspinNoiseError.self) {
            _ = try receiver.decrypt(ciphertext: ciphertext, associatedData: Data())
        }
    }

    @Test func authenticatesTheAssociatedData() throws {
        var sender = SendspinNoiseCipherState(key: key)
        var receiver = SendspinNoiseCipherState(key: key)
        let ciphertext = try sender.encrypt(plaintext: Data("hello".utf8), associatedData: Data([1, 2, 3]))
        #expect(throws: SendspinNoiseError.self) {
            _ = try receiver.decrypt(ciphertext: ciphertext, associatedData: Data([3, 2, 1]))
        }
    }

    /// The handshake's first messages are exchanged before any key exists, and pass through.
    @Test func passesThroughWithoutAKey() throws {
        var state = SendspinNoiseCipherState()
        let plaintext = Data("cleartext".utf8)
        #expect(try state.encrypt(plaintext: plaintext, associatedData: Data()) == plaintext)
        #expect(try state.decrypt(ciphertext: plaintext, associatedData: Data()) == plaintext)
    }
}
