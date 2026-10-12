import Foundation

/// What the server says it is using a referenced PSK as. A `psk_id` held only under a different
/// category is a lookup miss, so the category is part of the match rather than a hint.
enum SendspinPskCategory: String, Codable, Equatable {
    case longTerm = "lt"
    case pairing = "pr"
    case sentinel = "sn"
}
