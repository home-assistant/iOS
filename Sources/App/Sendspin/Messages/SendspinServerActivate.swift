import Foundation

/// `server/activate`: what the server is using this connection for, and which roles it turned on.
struct SendspinServerActivate: Codable, Equatable {
    let activities: [String]
    /// `nil` keeps the roles the previous activation set.
    let activeRoles: [String]?
    let pairing: SendspinActivatePairing?

    enum CodingKeys: String, CodingKey {
        case activities
        case activeRoles = "active_roles"
        case pairing
    }
}
