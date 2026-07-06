import Foundation

/// Umbrella namespace for the in-house WatchConnectivity layer that replaces the `Communicator` pod.
/// Types are nested here so they never collide with the pod's identically-named types while both
/// coexist during the migration.
public enum HAWatchConnectivity {
    public typealias Content = [String: Any]

    enum PayloadKey {
        static let identifier = "identifier"
        static let content = "content"
        static let complicationInfo = "__complication_info__"
    }
}
