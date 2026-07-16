import Foundation

/// A command awaiting its `result` (or `pong`) frame. Kept keyed by a stable token (not the wire
/// id) so it can be re-sent with a fresh id after a reconnect.
struct PendingRequest {
    let command: String
    let data: [String: HAAPIJSONValue]
    /// Heartbeat pings do not survive a reconnect; real commands do.
    let requeuesOnReconnect: Bool
    let continuation: CheckedContinuation<Data, any Error>
    /// The wire id of the in-flight send, nil while queued (pre-auth or awaiting re-send).
    var serverID: Int?
}
