import Foundation

/// Reads and writes the Wyoming wire format: one JSON header line terminated by `\n`, then
/// `data_length` bytes of JSON, then `payload_length` bytes of raw audio.
///
/// Decoding is incremental because the events arrive over TCP with no relationship to packet
/// boundaries — a single read can hold three events and half of a fourth.
enum WyomingEventCodec {
    /// Wyoming names its JSON keys in snake case (`data_length`, `payload_length`, `text_format`),
    /// so both coders convert rather than every model spelling out `CodingKeys`.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// Ceilings for what an unauthenticated peer on the local network can make this process buffer.
    /// A client that never sends a newline, or announces a body far larger than any real utterance,
    /// fails the connection instead of growing the buffer until the app is jetsammed.
    private enum Limits {
        static let header = 64 * 1024
        /// Roughly ten minutes of 16 kHz 16-bit mono audio, far past any single Wyoming event.
        static let body = 32 * 1024 * 1024
    }

    private static let newline = UInt8(0x0A)

    /// The header line as written; `data` and `payload` follow it as raw bytes.
    private struct Header: Encodable {
        let type: String
        let dataLength: Int?
        let payloadLength: Int?

        enum CodingKeys: String, CodingKey {
            case type
            case dataLength = "data_length"
            case payloadLength = "payload_length"
        }
    }

    static func encode(_ event: WyomingEvent) throws -> Data {
        let header = Header(
            type: event.type,
            dataLength: event.data.map(\.count),
            payloadLength: event.payload.map(\.count)
        )
        // Spelled out with `CodingKeys` and encoded by a plain encoder: the header travels
        // alongside data sections whose own key strategy must not reach it.
        var encoded = try JSONEncoder().encode(header)
        encoded.append(newline)
        if let data = event.data {
            encoded.append(data)
        }
        if let payload = event.payload {
            encoded.append(payload)
        }
        return encoded
    }

    /// Pulls the next complete event off the front of `buffer`, returning `nil` — and leaving the
    /// buffer untouched — while the event is still arriving.
    static func decode(from buffer: inout Data) throws -> WyomingEvent? {
        guard let newlineIndex = buffer.firstIndex(of: newline) else {
            guard buffer.count <= Limits.header else { throw WyomingProtocolError.eventTooLarge }
            return nil
        }

        let header = try parseHeader(Data(buffer[buffer.startIndex ..< newlineIndex]))
        let bodyStart = buffer.index(after: newlineIndex)
        let bodyLength = header.dataLength + header.payloadLength
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= bodyLength else { return nil }

        let dataEnd = buffer.index(bodyStart, offsetBy: header.dataLength)
        let payloadEnd = buffer.index(dataEnd, offsetBy: header.payloadLength)
        let data = header.dataLength > 0 ? Data(buffer[bodyStart ..< dataEnd]) : header.inlineData
        let payload = header.payloadLength > 0 ? Data(buffer[dataEnd ..< payloadEnd]) : nil
        buffer = Data(buffer[payloadEnd...])

        return WyomingEvent(type: header.type, data: data, payload: payload)
    }

    private struct ParsedHeader {
        let type: String
        let dataLength: Int
        let payloadLength: Int
        /// Older Wyoming senders put the data object straight into the header line instead of
        /// announcing a `data_length`, and the reference implementation still accepts both.
        let inlineData: Data?
    }

    private static func parseHeader(_ line: Data) throws -> ParsedHeader {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let type = object["type"] as? String else {
            throw WyomingProtocolError.malformedEvent
        }

        let dataLength = object["data_length"] as? Int ?? 0
        let payloadLength = object["payload_length"] as? Int ?? 0
        guard dataLength >= 0, payloadLength >= 0,
              dataLength <= Limits.body, payloadLength <= Limits.body else {
            throw WyomingProtocolError.eventTooLarge
        }

        var inlineData: Data?
        if dataLength == 0, let data = object["data"] as? [String: Any] {
            inlineData = try? JSONSerialization.data(withJSONObject: data)
        }

        return ParsedHeader(
            type: type,
            dataLength: dataLength,
            payloadLength: payloadLength,
            inlineData: inlineData
        )
    }
}
