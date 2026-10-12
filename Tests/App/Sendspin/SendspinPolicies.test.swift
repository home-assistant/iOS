import Foundation
@testable import HomeAssistant
import Testing

struct SendspinActivationPolicyTests {
    private func evaluate(
        _ activities: [String],
        roles: Bool = false,
        pairing: SendspinActivatePairing? = nil,
        category: SendspinPskCategory,
        unpairedAccess: Bool = true
    ) -> SendspinActivationDecision {
        SendspinActivationPolicy.evaluate(
            activities: activities,
            hasRoles: roles,
            pairing: pairing,
            category: category,
            unpairedAccess: unpairedAccess
        )
    }

    @Test func pairedSessionsMayPlayButNotPair() {
        #expect(evaluate([], category: .longTerm) == .accept)
        #expect(evaluate(["playback"], roles: true, category: .longTerm) == .accept)
        #expect(evaluate(["pairing"], category: .longTerm) == .goodbye(.unauthorized))
    }

    @Test func unpairedSessionsNeedUnpairedAccessToPlay() {
        #expect(evaluate(["playback"], roles: true, category: .sentinel) == .accept)
        #expect(
            evaluate(["playback"], roles: true, category: .sentinel, unpairedAccess: false)
                == .goodbye(.pairingRequired)
        )
        #expect(evaluate([], roles: true, category: .sentinel, unpairedAccess: false) == .goodbye(.pairingRequired))
        #expect(evaluate([], category: .sentinel, unpairedAccess: false) == .accept)
    }

    @Test func pairingMustUseThePairingPsk() {
        let pairingPsk = SendspinActivatePairing(method: "pairing_psk", format: nil)
        #expect(evaluate(["pairing"], pairing: pairingPsk, category: .pairing, unpairedAccess: false) == .accept)
        #expect(evaluate(["pairing"], pairing: pairingPsk, category: .sentinel) == .pairAbortMethodNotSupported)
        #expect(evaluate(
            ["pairing"],
            pairing: SendspinActivatePairing(method: "dynamic_pairing_code", format: "digits"),
            category: .sentinel
        ) == .pairAbortMethodNotSupported)
        #expect(evaluate(["pairing"], category: .pairing) == .pairAbortMethodNotSupported)
    }

    @Test func unknownActivitiesAreRefused() {
        #expect(evaluate(["dancing"], category: .longTerm) == .goodbye(.unauthorized))
    }
}

struct SendspinAdmissionPolicyTests {
    private func candidate(
        _ serverID: String,
        _ activities: [String],
        pairing: Bool = false
    ) -> SendspinAdmissionCandidate {
        SendspinAdmissionCandidate(serverID: serverID, activities: activities, isPairingInProgress: pairing)
    }

    @Test func admitsTheFirstConnection() {
        #expect(SendspinAdmissionPolicy.admits(candidate("a", []), over: nil, lastPlaybackServerID: nil))
    }

    @Test func higherOrEqualPriorityTakesOver() {
        #expect(SendspinAdmissionPolicy.admits(
            candidate("b", ["playback"]),
            over: candidate("a", ["playback"]),
            lastPlaybackServerID: nil
        ))
        #expect(SendspinAdmissionPolicy.admits(
            candidate("b", ["playback"]),
            over: candidate("a", ["pairing"]),
            lastPlaybackServerID: nil
        ))
        #expect(!SendspinAdmissionPolicy.admits(
            candidate("b", ["pairing"]),
            over: candidate("a", ["playback"]),
            lastPlaybackServerID: nil
        ))
        #expect(!SendspinAdmissionPolicy.admits(
            candidate("b", []),
            over: candidate("a", ["pairing"]),
            lastPlaybackServerID: nil
        ))
    }

    @Test func aPairingAttemptIsNeverCutShort() {
        #expect(!SendspinAdmissionPolicy.admits(
            candidate("b", ["playback"]),
            over: candidate("a", ["pairing"], pairing: true),
            lastPlaybackServerID: nil
        ))
    }

    @Test func theLastPlaybackServerWinsBetweenIdleOnes() {
        #expect(SendspinAdmissionPolicy.admits(candidate("b", []), over: candidate("a", []), lastPlaybackServerID: "b"))
        #expect(!SendspinAdmissionPolicy.admits(
            candidate("b", []),
            over: candidate("a", []),
            lastPlaybackServerID: "a"
        ))
        #expect(!SendspinAdmissionPolicy.admits(
            candidate("b", []),
            over: candidate("a", []),
            lastPlaybackServerID: nil
        ))
    }

    @Test func theSameServerReplacesItsOwnStaleConnection() {
        #expect(SendspinAdmissionPolicy.admits(
            candidate("a", []),
            over: candidate("a", ["playback"]),
            lastPlaybackServerID: nil
        ))
    }

    @Test func activitiesRankPlaybackAbovePairing() {
        #expect(SendspinActivity.pairing < .playback)
        #expect(candidate("a", ["pairing", "playback"]).activity == .playback)
    }
}
