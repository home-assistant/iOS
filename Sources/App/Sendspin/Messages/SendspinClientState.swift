import Foundation

/// `client/state`. `player` is left out while the role is inactive.
struct SendspinClientState: Codable, Equatable {
    let available: Bool
    let player: SendspinPlayerStateReport?
}
