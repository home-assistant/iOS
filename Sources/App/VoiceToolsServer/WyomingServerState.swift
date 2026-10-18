import Foundation

/// What the Wyoming listener is doing, as the settings screen shows it.
enum WyomingServerState: Equatable {
    case stopped
    case starting
    case running(port: UInt16)
    /// Carries the reason so a taken port or a refused local-network permission is visible in the
    /// app instead of only in the log.
    case failed(message: String)
}
