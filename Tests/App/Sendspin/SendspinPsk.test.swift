import Foundation
@testable import HomeAssistant
import Testing

struct SendspinPskTests {
    /// The Sentinel PSK and its identifier are published constants; a mismatch here means every
    /// unpaired handshake would fail.
    @Test func sentinelMatchesTheSpecifiedConstant() {
        let expected = Data([
            0x1B, 0x5E, 0x24, 0xDB, 0xC1, 0xAE, 0xD9, 0x5F,
            0xC2, 0xA5, 0xA3, 0x38, 0xA9, 0x0C, 0x05, 0xDF,
            0x44, 0xBD, 0x10, 0xF5, 0xEC, 0x1F, 0x4C, 0xD6,
            0x6C, 0xBF, 0x86, 0x27, 0x27, 0x67, 0xB9, 0xD3,
        ])
        #expect(SendspinPsk.sentinel.bytes == expected)
    }

    @Test func sentinelIdentifierMatchesTheSpecifiedConstant() {
        #expect(SendspinPsk.sentinel.identifier == "GFsV9tLaSQm9HcFWpKsgYQOr7wFTvNUtkmFwuVz3zoo")
    }

    @Test func identifierIsBase64URLOfThirtyTwoBytes() {
        let psk = SendspinPsk.generate()
        #expect(psk.identifier.count == 43)
        #expect(SendspinBase64URL.decode(psk.identifier)?.count == 32)
    }

    @Test func rejectsKeysOfTheWrongLength() {
        #expect(SendspinPsk(bytes: Data(repeating: 0, count: 31)) == nil)
        #expect(SendspinPsk(bytes: Data(repeating: 0, count: 32)) != nil)
    }

    @Test func generatesDistinctKeys() {
        #expect(SendspinPsk.generate() != SendspinPsk.generate())
    }
}
