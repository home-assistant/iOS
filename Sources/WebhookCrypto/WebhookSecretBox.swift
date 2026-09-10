import Foundation
import Sodium

/// The secretbox primitive Home Assistant's `mobile_app` webhook wraps payloads in.
///
/// Its own low-level source set so the phone's webhook path, the watch client and the RemoteMedia
/// extension all seal payloads with one implementation rather than diverging copies. The extension
/// has a 6144 KB ledger and cannot link `Shared`; this depends on nothing but Foundation and
/// `Sodium`, which is statically linked and contributes only the secretbox and base64 objects.
public enum WebhookSecretBox {
    public enum CryptoError: Error, Equatable {
        case encode
        case seal
        case base64
        case decode
        case open
    }

    /// `object` (a JSON value) sealed with `secret` and base64-encoded, ready to be sent as a
    /// request's `encrypted_data`.
    public static func seal(_ object: Any, secret: [UInt8], sodium: Sodium = Sodium()) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let json = String(data: jsonData, encoding: .utf8) else { throw CryptoError.encode }
        guard let sealed: Bytes = sodium.secretBox.seal(message: json.bytes, secretKey: .init(secret)) else {
            throw CryptoError.seal
        }
        guard let encoded = sodium.utils.bin2base64(sealed, variant: .ORIGINAL) else {
            throw CryptoError.base64
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
            throw CryptoError.decode
        }
        guard let opened = sodium.secretBox.open(
            nonceAndAuthenticatedCipherText: decoded,
            secretKey: .init(secret)
        ) else {
            throw CryptoError.open
        }
        guard !opened.isEmpty else { return () }
        return try JSONSerialization.jsonObject(with: Data(opened), options: options)
    }
}
