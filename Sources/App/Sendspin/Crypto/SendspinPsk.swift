import CryptoKit
import Foundation

/// A 32-byte Sendspin pre-shared key, together with the identifier a server references it by.
struct SendspinPsk: Hashable {
    static let byteCount = 32

    /// The published constant a server uses whenever no other PSK applies. It authenticates
    /// nothing on its own — a Sentinel session is unpaired until pairing establishes a record.
    static let sentinel = SendspinPsk(unchecked: Data(SHA256.hash(data: Data("sendspin-sentinel-psk-v1".utf8))))

    let bytes: Data

    init?(bytes: Data) {
        guard bytes.count == Self.byteCount else { return nil }
        self.bytes = bytes
    }

    private init(unchecked bytes: Data) {
        self.bytes = bytes
    }

    static func generate() -> SendspinPsk {
        SendspinPsk(unchecked: SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) })
    }

    /// `psk_id = base64url(SHA-256("sendspin-psk-id-v1" || PSK))`.
    var identifier: String {
        var input = Data("sendspin-psk-id-v1".utf8)
        input.append(bytes)
        return SendspinBase64URL.encode(Data(SHA256.hash(data: input)))
    }
}
