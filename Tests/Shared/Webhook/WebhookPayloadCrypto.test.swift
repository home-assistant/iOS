import Foundation
@testable import Shared
import Testing

struct WebhookPayloadCryptoTests {
    private let secret: [UInt8] = Array(0 ..< 32)

    @Test func encryptsAndDecryptsAnObject() throws {
        let sealed = try WebhookPayloadCrypto.encrypt(["type": "test", "value": 1], secret: secret)
        let opened = try WebhookPayloadCrypto.decrypt(sealed, secret: secret)

        let dictionary = try #require(opened as? [String: Any])
        #expect(dictionary["type"] as? String == "test")
        #expect(dictionary["value"] as? Int == 1)
    }

    @Test func wrongKeyFailsToOpen() throws {
        let sealed = try WebhookPayloadCrypto.encrypt(["type": "test"], secret: secret)

        #expect(throws: WebhookJsonParseError.decrypt) {
            try WebhookPayloadCrypto.decrypt(sealed, secret: Array(repeating: 9, count: 32))
        }
    }

    @Test func invalidBase64FailsBeforeOpening() {
        #expect(throws: WebhookJsonParseError.base64) {
            try WebhookPayloadCrypto.decrypt("not base64!", secret: secret)
        }
    }
}
