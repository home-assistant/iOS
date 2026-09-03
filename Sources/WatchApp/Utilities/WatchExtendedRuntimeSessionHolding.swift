import Foundation

/// Something that keeps the watch app running across a wrist-down for the duration of an operation.
/// Abstracted from `WatchExtendedRuntimeSessionManager` so view models can be built without WatchKit's
/// real session (previews, tests).
protocol WatchExtendedRuntimeSessionHolding: AnyObject {
    /// Hold the session open on behalf of `reason`. Idempotent per reason.
    func begin(_ reason: WatchExtendedRuntimeSessionManager.Reason)
    /// Release `reason`'s hold; the session ends once no reason holds it. Safe without a matching `begin`.
    func end(_ reason: WatchExtendedRuntimeSessionManager.Reason)
}
