import Foundation

/// A single Wyoming protocol message: a type, an optional JSON object and an optional binary
/// payload.
///
/// `data` stays as encoded bytes instead of a decoded dictionary because a peer sends event types
/// this server does not implement. Only the handled ones decode themselves out of it, so the rest
/// pass through without their schemas ever being modelled.
struct WyomingEvent: Equatable {
    /// The event types this server reads or writes. Anything else is answered with an `error` or
    /// ignored, which is why unknown types deliberately stay unmodelled.
    enum Kind: String {
        case describe
        case info
        case transcribe
        case transcript
        case synthesize
        case audioStart = "audio-start"
        case audioChunk = "audio-chunk"
        case audioStop = "audio-stop"
        case ping
        case pong
        case error
    }

    let type: String
    let data: Data?
    let payload: Data?

    var kind: Kind? { Kind(rawValue: type) }

    init(type: String, data: Data? = nil, payload: Data? = nil) {
        self.type = type
        self.data = data
        self.payload = payload
    }

    init(kind: Kind, data: Data? = nil, payload: Data? = nil) {
        self.init(type: kind.rawValue, data: data, payload: payload)
    }

    /// Builds an event whose data section is `value` encoded as Wyoming's snake-cased JSON.
    init(kind: Kind, encoding value: some Encodable, payload: Data? = nil) throws {
        try self.init(kind: kind, data: WyomingEventCodec.encoder.encode(value), payload: payload)
    }

    /// Decodes the data section, throwing when the peer sent the event without one.
    func decodeData<Value: Decodable>(_ valueType: Value.Type = Value.self) throws -> Value {
        guard let data else { throw WyomingProtocolError.missingEventData(type) }
        return try WyomingEventCodec.decoder.decode(Value.self, from: data)
    }
}
