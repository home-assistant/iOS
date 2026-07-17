/// Second-pass decode of a successful `result` frame, performed by the caller that knows the
/// concrete `Response` type.
struct ResultEnvelope<R: Decodable>: Decodable {
    var result: R
}
