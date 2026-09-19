import Foundation
import Sodium

/// The secretbox primitive Home Assistant's `mobile_app` webhook wraps payloads in.
///
/// Kept in its own package so lightweight targets can link it without the full `Shared` module.
public enum WebhookSecretBox {
    /// Why a payload could not be sealed.
    public enum SealError: Error, Equatable {
        case encode
        case seal
        case base64
    }

    /// Why a sealed payload could not be opened.
    public enum OpenError: Error, Equatable {
        case decode
        case open
    }

    /// `object` (a JSON object) sealed with `secret` and base64-encoded, ready to be sent as a
    /// request's `encrypted_data`.
    public static func seal(_ object: Any, secret: [UInt8], sodium: Sodium = Sodium()) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let json = String(data: jsonData, encoding: .utf8) else { throw SealError.encode }
        guard let sealed: Bytes = sodium.secretBox.seal(message: json.bytes, secretKey: .init(secret)) else {
            throw SealError.seal
        }
        guard let encoded = sodium.utils.bin2base64(sealed, variant: .ORIGINAL) else {
            throw SealError.base64
        }
        return encoded
    }

    /// The JSON an `encrypted_data` value holds, or `()` when the sealed payload was empty.
    public static func open(
        _ encoded: String,
        secret: [UInt8],
        sodium: Sodium = Sodium(),
        options: JSONSerialization.ReadingOptions = [.allowFragments]
    ) throws -> Any {
        guard let decoded = sodium.utils.base642bin(encoded, variant: .ORIGINAL, ignore: nil) else {
            throw OpenError.decode
        }
        guard let opened = sodium.secretBox.open(
            nonceAndAuthenticatedCipherText: decoded,
            secretKey: .init(secret)
        ) else {
            throw OpenError.open
        }
        guard !opened.isEmpty else { return () }
        return try JSONSerialization.jsonObject(with: Data(opened), options: options)
    }
}
