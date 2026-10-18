import Foundation
import Sodium
import WebhookCrypto

/// The secretbox encryption Home Assistant's `mobile_app` webhook wraps payloads in, shared by the
/// phone's `WebhookRequest` path and the watch's own webhook client so both encode the same way.
///
/// The primitive itself lives in the `WebhookCrypto` package.
enum WebhookPayloadCrypto {
    /// `data` (a JSON object) sealed with `secret` and base64-encoded, ready to be sent as the
    /// request's `encrypted_data` value.
    static func encrypt(_ data: Any, secret: [UInt8], sodium: Sodium = Sodium()) throws -> String {
        try WebhookSecretBox.seal(data, secret: secret, sodium: sodium)
    }

    /// The JSON a response's `encrypted_data` value holds, or `()` when the server sealed an empty
    /// payload.
    static func decrypt(
        _ encoded: String,
        secret: [UInt8],
        sodium: Sodium = Sodium(),
        options: JSONSerialization.ReadingOptions = [.allowFragments]
    ) throws -> Any {
        do {
            return try WebhookSecretBox.open(encoded, secret: secret, sodium: sodium, options: options)
        } catch let error as WebhookSecretBox.OpenError {
            switch error {
            case .decode:
                throw WebhookJsonParseError.base64
            case .open:
                throw WebhookJsonParseError.decrypt
            }
        }
    }
}
