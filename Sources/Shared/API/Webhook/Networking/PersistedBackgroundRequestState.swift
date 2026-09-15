import Foundation

public enum PersistedBackgroundRequestState {
    case running(Task<Void, Error>)
    case completed(Result<Void, Error>)
    /// Task lookup did not complete. Keep the delivery marker and reconcile again; do not resend.
    case unavailable(Error)
    case absent
}
