import Foundation
import Sodium

/// The secretbox encryption Home Assistant's `mobile_app` webhook wraps payloads in, shared by the
/// phone's `WebhookRequest` path and the watch's own webhook client so both encode the same way.
///
/// The primitive itself lives in `WebhookSecretBox`, which the RemoteMedia extension also
/// compiles: that process cannot link this module, and two implementations of a wire format is how
/// they drift apart. This keeps the error types the webhook stack already throws.
enum WebhookPayloadCrypto {
    enum CryptoError: Error, Equatable {
        case encode
        case seal
        case base64
    }

    /// `data` (a JSON object) sealed with `secret` and base64-encoded, ready to be sent as the
    /// request's `encrypted_data` value.
    static func encrypt(_ data: Any, secret: [UInt8], sodium: Sodium = Sodium()) throws -> String {
        do {
            return try WebhookSecretBox.seal(data, secret: secret, sodium: sodium)
        } catch WebhookSecretBox.CryptoError.encode {
            throw CryptoError.encode
        } catch WebhookSecretBox.CryptoError.seal {
            throw CryptoError.seal
        } catch WebhookSecretBox.CryptoError.base64 {
            throw CryptoError.base64
        }
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
        } catch WebhookSecretBox.CryptoError.decode {
            throw WebhookJsonParseError.base64
        } catch WebhookSecretBox.CryptoError.open {
            throw WebhookJsonParseError.decrypt
        }
    }
}
