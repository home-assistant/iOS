import Foundation

public enum PersistedBackgroundRequestState {
    case running(Task<Void, Error>)
    /// A restored upload result that reconciliation consumes once. A later lookup for the same
    /// identifier may be `.absent`; callers must not treat that as proof that no upload ran.
    case completed(Result<Void, Error>)
    /// Task lookup did not complete. Keep the delivery marker and reconcile again; do not resend.
    case unavailable(Error)
    case absent
}
