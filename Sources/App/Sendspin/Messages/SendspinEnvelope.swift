import Foundation

/// Every Sendspin JSON message: a `type` naming it and a `payload` object whose shape the type
/// decides.
struct SendspinEnvelope<Payload: Codable>: Codable {
    let type: String
    let payload: Payload
}
