import Foundation

/// `client/pair-finalize` in the Pairing PSK flow: the new long-term PSK, which the session's
/// pairing-PSK encryption already protects.
struct SendspinPairFinalize: Codable, Equatable {
    let longTermPsk: String

    enum CodingKeys: String, CodingKey {
        case longTermPsk = "long_term_psk"
    }
}
