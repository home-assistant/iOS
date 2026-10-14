import CryptoKit
import Foundation

/// A SHA-256 digest in lowercase hexadecimal: the form an identifier takes in a snapshot instead of the
/// raw integration value (`media_content_id` can be a signed stream URL).
///
/// That keeps the plaintext from being embedded, not from being correlated: equal inputs give equal
/// digests, and a guessable input can be confirmed by hashing a guess. It is an identifier, not a secret.
///
/// `init(hashing:)` is `hashlib.sha256(value.encode()).hexdigest()` in Python: the string's UTF-8 bytes
/// exactly as received, with no Unicode normalization.
public struct RemoteMediaDigest: Hashable, Sendable {
    /// 64 lowercase hexadecimal characters.
    public let hexString: String

    /// The digest of `value`'s UTF-8 bytes.
    init(hashing value: String) {
        self.hexString = SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// The digest of several fields that must not run together: each is written as its UTF-8 byte
    /// count, a colon and the value, and a missing one as `-`, so no two lists share a preimage.
    init(hashingFields fields: [String?]) {
        self.init(hashing: fields.map { $0.map { "\($0.utf8.count):\($0)" } ?? "-" }.joined())
    }
}
