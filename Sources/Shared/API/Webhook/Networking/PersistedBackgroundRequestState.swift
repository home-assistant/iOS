import Foundation

public enum PersistedBackgroundRequestState {
    case running(Task<Void, Error>)
    case completed(Result<Void, Error>)
    case absent
}
