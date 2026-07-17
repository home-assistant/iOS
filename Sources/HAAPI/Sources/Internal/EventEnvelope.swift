/// Second-pass decode of an `event` frame, performed by the subscription that knows the
/// concrete `Event` type.
struct EventEnvelope<E: Decodable>: Decodable {
    var event: E
}
