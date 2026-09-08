import Foundation
import OSLog

/// Extension-safe logging for Remote Now Playing.
///
/// This deliberately does not use `Current.Log`: touching that dependency from the RemoteMedia
/// extension can re-enter global environment initialization while the extension is launching.
public enum RemoteMediaLog {
    public static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.home-assistant.RemoteMedia",
        category: "RemoteMedia"
    )
}
