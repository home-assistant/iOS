import Foundation

/// A live subscription. Keeps the original command so it can be transparently re-issued with a
/// fresh wire id after a reconnect while the consumer keeps iterating the same stream.
struct SubscriptionRecord {
    let command: String
    let data: [String: HAAPIJSONValue]
    /// Decodes an `event` frame's typed payload and yields it to the consumer's stream.
    let yieldEvent: @Sendable (Data) throws -> Void
    let finish: @Sendable ((any Error)?) -> Void
    var serverID: Int?
    var isConfirmed = false
}
