import Foundation

/// A server this device has paired with: the long-term PSK both sides persisted, bound to the
/// server identity it was established with.
struct SendspinPairingRecord: Codable, Equatable, Identifiable {
    let serverID: String
    let serverName: String
    /// Base64url, as everywhere else Sendspin keys are written down.
    let psk: String
    var lastUsed: Date

    var id: String { serverID }

    var pskValue: SendspinPsk? {
        SendspinBase64URL.decode(psk).flatMap { SendspinPsk(bytes: $0) }
    }
}
