import Foundation

/// The `pairing` object of `server/activate`: which method the server picked for the attempt.
struct SendspinActivatePairing: Codable, Equatable {
    let method: String
    let format: String?
}
