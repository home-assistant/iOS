import Foundation

/// The version-0 pairing token: the client's public key and its pairing PSK in one case-insensitive
/// ASCII string the operator transfers into the server by scanning a QR code or pasting the text.
///
/// The body is base32 (RFC 4648) with padding stripped and every `2` transliterated to `9`, so the
/// whole token stays inside the QR alphanumeric set.
struct SendspinPairingToken: Equatable {
    let clientKey: Data
    let pairingPsk: SendspinPsk

    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    var string: String {
        "SP:0" + Self.encodeBody(clientKey + pairingPsk.bytes)
    }

    init(clientKey: Data, pairingPsk: SendspinPsk) {
        self.clientKey = clientKey
        self.pairingPsk = pairingPsk
    }

    init?(string: String) {
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let withoutPrefix = normalized.hasPrefix("SP:") ? String(normalized.dropFirst(3)) : normalized
        guard withoutPrefix.first == "0" else { return nil }
        guard let payload = Self.decodeBody(String(withoutPrefix.dropFirst())), payload.count >= 64 else {
            return nil
        }
        guard let psk = SendspinPsk(bytes: Data(payload[payload.startIndex + 32 ..< payload.startIndex + 64])) else {
            return nil
        }
        clientKey = Data(payload[payload.startIndex ..< payload.startIndex + 32])
        pairingPsk = psk
    }

    static func encodeBody(_ data: Data) -> String {
        var output = ""
        var accumulator = 0
        var bits = 0
        for byte in data {
            accumulator = (accumulator << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                output.append(alphabet[(accumulator >> bits) & 0x1F])
            }
        }
        if bits > 0 {
            output.append(alphabet[(accumulator << (5 - bits)) & 0x1F])
        }
        return output.replacingOccurrences(of: "2", with: "9")
    }

    static func decodeBody(_ body: String) -> Data? {
        var accumulator = 0
        var bits = 0
        var output = Data()
        for character in body.replacingOccurrences(of: "9", with: "2") {
            guard let value = alphabet.firstIndex(of: character) else { return nil }
            accumulator = (accumulator << 5) | value
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((accumulator >> bits) & 0xFF))
            }
        }
        // Trailing bits only pad the last byte; anything set there is a corrupt token.
        guard bits == 0 || (accumulator & ((1 << bits) - 1)) == 0 else { return nil }
        return output
    }
}
