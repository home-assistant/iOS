import Foundation

/// The specification's rules for which activities and roles a server may declare, given the PSK
/// the handshake matched and whether this device admits unpaired access.
enum SendspinActivationPolicy {
    static let pairingPskMethod = "pairing_psk"

    static func isAllowed(
        _ activities: Set<SendspinActivity>,
        category: SendspinPskCategory,
        unpairedAccess: Bool
    ) -> Bool {
        switch category {
        case .longTerm:
            return activities.isSubset(of: [.playback])
        case .pairing, .sentinel:
            return activities.isSubset(of: unpairedAccess ? [.playback, .pairing] : [.pairing])
        }
    }

    /// Only a connection that could declare playback may carry roles.
    static func isPlaybackCapable(
        _ activities: Set<SendspinActivity>,
        category: SendspinPskCategory,
        unpairedAccess: Bool
    ) -> Bool {
        isAllowed(activities.union([.playback]), category: category, unpairedAccess: unpairedAccess)
    }

    static func evaluate(
        activities rawActivities: [String],
        hasRoles: Bool,
        pairing: SendspinActivatePairing?,
        category: SendspinPskCategory,
        unpairedAccess: Bool
    ) -> SendspinActivationDecision {
        let activities = Set(rawActivities.compactMap(SendspinActivity.init(rawValue:)))
        // An activity this device does not know cannot be shown to be allowed.
        guard activities.count == Set(rawActivities).count else { return .goodbye(.unauthorized) }

        func admissible(unpairedAccess: Bool) -> Bool {
            isAllowed(activities, category: category, unpairedAccess: unpairedAccess) &&
                (!hasRoles || isPlaybackCapable(activities, category: category, unpairedAccess: unpairedAccess))
        }

        guard admissible(unpairedAccess: unpairedAccess) else {
            if category != .longTerm, !unpairedAccess, admissible(unpairedAccess: true) {
                return .goodbye(.pairingRequired)
            }
            return .goodbye(.unauthorized)
        }

        if activities.contains(.pairing) {
            // `pairing_psk` is the only method offered, and it is only valid on a session keyed by
            // the pairing PSK.
            guard let pairing, pairing.method == pairingPskMethod, category == .pairing else {
                return .pairAbortMethodNotSupported
            }
        }
        return .accept
    }
}
