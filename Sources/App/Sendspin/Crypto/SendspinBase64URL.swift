import Foundation

/// Base64url without padding (RFC 4648 §5): how Sendspin carries identities, PSK identifiers and
/// Noise handshake bytes inside JSON.
enum SendspinBase64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ string: String) -> Data? {
        // Standard base64 characters are not part of the url alphabet; accepting them would let
        // two different strings name the same key.
        guard !string.contains(where: { $0 == "+" || $0 == "/" || $0 == "=" }) else { return nil }
        var value = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = value.count % 4
        if remainder > 0 {
            value.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: value)
    }
}
