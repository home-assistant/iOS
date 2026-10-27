import Foundation

/// The owner of a session: decides admission, keeps the settings and hears what happened.
protocol SendspinSessionHost: AnyObject, Sendable {
    /// Asked once, when the server's first activation is admissible. `false` turns the session
    /// away as if it were of lower priority.
    func admit(_ session: SendspinSession, candidate: SendspinAdmissionCandidate) async -> Bool
    func session(_ session: SendspinSession, didReport event: SendspinSessionEvent) async
    func sessionDidClose(_ session: SendspinSession) async
}
