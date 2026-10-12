import Foundation

/// Decodes any payload the session sends, including ones the app itself only ever encodes.
struct SendspinTestEnvelope<Payload: Decodable>: Decodable {
    let type: String
    let payload: Payload
}
