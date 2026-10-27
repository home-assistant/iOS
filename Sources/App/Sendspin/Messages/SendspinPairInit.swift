import Foundation

/// `client/pair-init`. In the Pairing PSK flow it carries only the pairing index.
struct SendspinPairInit: Codable, Equatable {
    let pairingIndex: Int

    enum CodingKeys: String, CodingKey {
        case pairingIndex = "pairing_index"
    }
}
