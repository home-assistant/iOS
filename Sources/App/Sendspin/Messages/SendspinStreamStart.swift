import Foundation

/// `stream/start`. Sent again for a running stream to change its format in place.
struct SendspinStreamStart: Codable, Equatable {
    let player: SendspinStreamFormat?
}
