#if os(watchOS)
import Foundation

enum WatchDirectSyncError: Error {
    case noActiveURL
    case timedOut
    case unexpectedPayload(String)
}
#endif
