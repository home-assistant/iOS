import Foundation

/// Which connection keeps this device when a server connects while another holds it.
///
/// The player holds one connection at a time. A newcomer of higher or equal priority takes over,
/// except that a pairing attempt is never cut short, and between two idle servers the one that
/// last played here wins.
enum SendspinAdmissionPolicy {
    static func admits(
        _ incoming: SendspinAdmissionCandidate,
        over current: SendspinAdmissionCandidate?,
        lastPlaybackServerID: String?
    ) -> Bool {
        guard let current else { return true }
        // The same server connecting again has given up on its old connection, which is only
        // still here because the network has not told this device yet.
        if incoming.serverID == current.serverID {
            return true
        }
        if current.isPairingInProgress, incoming.activity != nil {
            return false
        }
        if incoming.activity == nil, current.activity == nil {
            return incoming.serverID == lastPlaybackServerID && current.serverID != lastPlaybackServerID
        }
        return incoming >= current
    }
}
