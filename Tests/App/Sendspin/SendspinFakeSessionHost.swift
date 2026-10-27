import Foundation
@testable import HomeAssistant

/// Admits (or refuses) sessions and records what they report.
actor SendspinFakeSessionHost: SendspinSessionHost {
    private(set) var admits = true
    private(set) var candidates: [SendspinAdmissionCandidate] = []
    private(set) var events: [SendspinSessionEvent] = []
    private(set) var closeCount = 0

    func setAdmits(_ admits: Bool) {
        self.admits = admits
    }

    func admit(_ session: SendspinSession, candidate: SendspinAdmissionCandidate) async -> Bool {
        candidates.append(candidate)
        return admits
    }

    func session(_ session: SendspinSession, didReport event: SendspinSessionEvent) async {
        events.append(event)
    }

    func sessionDidClose(_ session: SendspinSession) async {
        closeCount += 1
    }
}
