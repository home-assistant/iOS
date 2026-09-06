import Foundation

/// A decoded `server/activate`: what the server intends to do on this connection, and which of the
/// roles this client offered it actually turned on.
struct SendspinActivation: Decodable, Equatable {
    struct Pairing: Decodable, Equatable {
        let method: String
        let format: String?
    }

    let activities: [String]
    /// Absent on a later activation means "keep the roles from the previous one".
    let activeRoles: [String]?
    let pairing: Pairing?

    enum CodingKeys: String, CodingKey {
        case activities
        case activeRoles = "active_roles"
        case pairing
    }

    var isPlayback: Bool { activities.contains("playback") }
    var isPairing: Bool { activities.contains("pairing") }
}
