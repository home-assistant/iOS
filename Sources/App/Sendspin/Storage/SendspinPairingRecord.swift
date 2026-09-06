import Foundation

/// A long-term PSK persisted alongside the `server_id` that pairing produced it with. A handshake
/// naming this record's `psk_id` is what turns a session from unpaired into an authenticated one.
struct SendspinPairingRecord: Codable, Equatable {
    let pskBytes: Data
    let serverId: String
    var lastUsed: Date

    enum CodingKeys: String, CodingKey {
        case pskBytes = "psk"
        case serverId = "server_id"
        case lastUsed = "last_used"
    }

    var psk: SendspinPsk? {
        SendspinPsk(bytes: pskBytes)
    }

    var pskId: String? {
        psk?.identifier
    }
}
