import Foundation

/// Decoded first, on its own, so the type can pick the payload to decode the message as.
struct SendspinMessageHeader: Decodable {
    let type: String
}
