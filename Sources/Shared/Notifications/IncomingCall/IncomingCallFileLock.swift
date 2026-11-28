import Foundation

/// Serializes read-check-write sequences on the incoming-call state kept in the App Group defaults, across the
/// app and the PushProvider extension.
///
/// The two processes share the defaults but not an `NSLock`, so a check-and-record (the guard) or a
/// read-and-clear (the pending-end queue) could interleave. `flock` on a file in the App Group container is
/// held across processes; it is released when the descriptor closes, so a crashed holder never leaves it taken.
enum IncomingCallFileLock {
    private static let inProcess = NSLock()

    static func withLock<T>(_ body: () throws -> T) rethrows -> T {
        // flock is per open file description, so threads of one process also exclude each other; the
        // in-process lock just avoids opening a descriptor per waiting thread.
        inProcess.lock()
        defer { inProcess.unlock() }

        let path = AppConstants.AppGroupContainer.appendingPathComponent("incoming-call.lock").path
        let descriptor = open(path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            // Without the file the in-process lock still holds; at worst the two processes race as before.
            Current.Log.error("could not open the incoming call lock: \(errno)")
            return try body()
        }
        defer { close(descriptor) }

        while flock(descriptor, LOCK_EX) != 0, errno == EINTR {}
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}
