import Foundation

/// `supported_pair_methods` of `client/hello`. Every client offers the Pairing PSK method; the
/// code-based methods need a PAKE this player does not implement, so they are never offered.
struct SendspinSupportedPairMethods: Codable, Equatable {
    let pairingPsk: SendspinPairMethodDescriptor

    enum CodingKeys: String, CodingKey {
        case pairingPsk = "pairing_psk"
    }
}
