import Foundation
import Sodium

/// The secretbox encryption Home Assistant's `mobile_app` webhook wraps payloads in, shared by the
/// phone's `WebhookRequest` path and the watch's own webhook client so both encode the same way.
enum WebhookPayloadCrypto {
    enum CryptoError: Error, Equatable {
        case encode
        case seal
        case base64
    }

    /// `data` (a JSON object) sealed with `secret` and base64-encoded, ready to be sent as the
    /// request's `encrypted_data` value.
    static func encrypt(_ data: Any, secret: [UInt8], sodium: Sodium = Sodium()) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.sortedKeys])

        guard let jsonStr = String(data: jsonData, encoding: .utf8) else {
            throw CryptoError.encode
        }

        guard let encryptedData: Bytes = sodium.secretBox.seal(
            message: jsonStr.bytes,
            secretKey: .init(secret)
        ) else {
            throw CryptoError.seal
        }

        guard let b64payload = sodium.utils.bin2base64(encryptedData, variant: .ORIGINAL) else {
            throw CryptoError.base64
        }

        return b64payload
    }

    /// The JSON a response's `encrypted_data` value holds, or `()` when the server sealed an empty
    /// payload.
    static func decrypt(
        _ encoded: String,
        secret: [UInt8],
        sodium: Sodium = Sodium(),
        options: JSONSerialization.ReadingOptions = [.allowFragments]
    ) throws -> Any {
        guard let decoded = sodium.utils.base642bin(encoded, variant: .ORIGINAL, ignore: nil) else {
            throw WebhookJsonParseError.base64
        }

        guard let decrypted = sodium.secretBox.open(
            nonceAndAuthenticatedCipherText: decoded,
            secretKey: .init(secret)
        ) else {
            throw WebhookJsonParseError.decrypt
        }

        if decrypted.isEmpty {
            return ()
        } else {
            return try JSONSerialization.jsonObject(with: Data(decrypted), options: options)
        }
    }
}
