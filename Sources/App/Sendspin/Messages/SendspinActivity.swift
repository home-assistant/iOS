import Foundation

/// A purpose a server can declare for a connection. Ordered by the rank admission compares when a
/// second server connects.
enum SendspinActivity: String, Codable, Comparable {
    case pairing
    case playback

    private var rank: Int {
        switch self {
        case .pairing: return 1
        case .playback: return 2
        }
    }

    static func < (lhs: SendspinActivity, rhs: SendspinActivity) -> Bool {
        lhs.rank < rhs.rank
    }
}
