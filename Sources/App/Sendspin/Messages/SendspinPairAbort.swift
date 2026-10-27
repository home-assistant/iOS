import Foundation

/// `pair/abort`: ends a pairing attempt, in either direction.
struct SendspinPairAbort: Codable, Equatable {
    let reason: String
}
