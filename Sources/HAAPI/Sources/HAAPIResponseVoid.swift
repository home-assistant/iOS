/// Decodes successfully from any `result` payload, including `null` — for commands whose result
/// carries nothing useful (e.g. `call_service` without `return_response`).
public struct HAAPIResponseVoid: Decodable, Sendable {
    public init() {}
    public init(from decoder: Decoder) throws {}
}
