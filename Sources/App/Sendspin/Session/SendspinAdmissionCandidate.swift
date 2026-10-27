import Foundation

/// A connection as admission sees it when a second server shows up.
struct SendspinAdmissionCandidate: Equatable {
    let serverID: String
    /// The highest-ranked activity it declared, `nil` for none.
    let activity: SendspinActivity?
    let isPairingInProgress: Bool

    init(serverID: String, activities: [String], isPairingInProgress: Bool = false) {
        self.serverID = serverID
        self.activity = activities.compactMap(SendspinActivity.init(rawValue:)).max()
        self.isPairingInProgress = isPairingInProgress
    }

    fileprivate var rank: Int {
        switch activity {
        case .none: return 0
        case .pairing: return 1
        case .playback: return 2
        }
    }

    static func >= (lhs: SendspinAdmissionCandidate, rhs: SendspinAdmissionCandidate) -> Bool {
        lhs.rank >= rhs.rank
    }
}
