import Foundation

/// The payload of Noise message 1: which PSK the server keyed the handshake with, so this device
/// can pick the matching one before message 2 mixes it in.
struct SendspinPskReference: Codable, Equatable {
    let pskID: String
    let category: SendspinPskCategory

    enum CodingKeys: String, CodingKey {
        case pskID = "psk_id"
        case category = "psk_category"
    }
}
