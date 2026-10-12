import Foundation

/// The parts of the player's configuration a session reports to its server.
struct SendspinPlayerSettings: Equatable {
    var name: String
    var volume: Int
    var isMuted: Bool
    var outputDelayMs: Int
    var allowsUnpairedAccess: Bool
}
