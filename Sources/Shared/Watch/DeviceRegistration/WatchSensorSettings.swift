import Foundation

/// The watch-local choices and status the sensor reporter reads and writes. `WatchUserDefaults`
/// is the real store on the watch; the protocol keeps the reporter compilable and testable on
/// every platform.
public protocol WatchSensorSettings: AnyObject {
    /// Unique IDs of the sensors the user switched on for one server. Every sensor is opt-in, and
    /// each server has its own selection.
    func enabledSensorIDs(forServer serverID: Identifier<Server>) -> Set<String>
    /// When the watch last sent its sensors successfully. `nil` until the first success.
    var lastSensorReportAt: Date? { get set }
    /// What the most recent run's first failure said, or `nil` when it had none.
    var lastSensorReportError: String? { get set }
}
