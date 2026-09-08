import Foundation
@testable import Shared
import Testing

struct RemoteMediaPushTokenTests {
    private let token = RemoteMediaPushToken(Data([0x00, 0x0F, 0xA0, 0xFF, 0x10]))

    /// APNs addresses a device by the lowercase hexadecimal form, leading zeros included.
    @Test func hexIsLowercaseAndPadded() {
        #expect(token.hex == "000fa0ff10")
        #expect(token.byteCount == 5)
    }

    @Test func emptyTokenHasEmptyHex() {
        #expect(RemoteMediaPushToken(Data()).hex.isEmpty)
    }

    @Test func fingerprintIsStableAndShort() {
        let again = RemoteMediaPushToken(Data([0x00, 0x0F, 0xA0, 0xFF, 0x10]))
        #expect(token.fingerprint == again.fingerprint)
        #expect(token.fingerprint.count == 8)
    }

    /// The fingerprint is what logs and de-duplication use, so a different token has to look
    /// different — and the token itself must not be recoverable from it.
    @Test func fingerprintDistinguishesTokensWithoutRevealingThem() {
        let other = RemoteMediaPushToken(Data([0x00, 0x0F, 0xA0, 0xFF, 0x11]))
        #expect(token.fingerprint != other.fingerprint)
        #expect(!token.hex.contains(token.fingerprint))
    }
}
