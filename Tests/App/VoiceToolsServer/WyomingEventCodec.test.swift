import Foundation
@testable import HomeAssistant
import Testing

struct WyomingEventCodecTests {
    /// Reproduces what the reference implementation writes: a JSON header line, then the data
    /// section, then the payload.
    private func frame(type: String, data: String?, payload: Data?) -> Data {
        var header: [String: Any] = ["type": type]
        if let data {
            header["data_length"] = data.utf8.count
        }
        if let payload {
            header["payload_length"] = payload.count
        }
        var frame = try! JSONSerialization.data(withJSONObject: header)
        frame.append(0x0A)
        if let data {
            frame.append(Data(data.utf8))
        }
        if let payload {
            frame.append(payload)
        }
        return frame
    }

    @Test func decodesHeaderDataAndPayload() throws {
        var buffer = frame(
            type: "audio-chunk",
            data: #"{"rate":16000,"width":2,"channels":1}"#,
            payload: Data([1, 2, 3, 4])
        )

        let decoded = try WyomingEventCodec.decode(from: &buffer)
        let event = try #require(decoded)

        #expect(event.type == "audio-chunk")
        #expect(event.kind == .audioChunk)
        #expect(event.payload == Data([1, 2, 3, 4]))
        let format = try event.decodeData(WyomingAudioFormat.self)
        #expect(format == WyomingAudioFormat(rate: 16000, width: 2, channels: 1))
        #expect(buffer.isEmpty)
    }

    /// TCP hands over whatever has arrived, so an event is routinely split across reads and must
    /// stay in the buffer until all of it is there.
    @Test func waitsForAnIncompleteEvent() throws {
        let complete = frame(type: "transcribe", data: #"{"language":"en-US"}"#, payload: nil)

        for split in 1 ..< complete.count {
            var buffer = Data(complete.prefix(split))
            let decoded = try WyomingEventCodec.decode(from: &buffer)
            #expect(decoded == nil)
            #expect(buffer.count == split, "an incomplete event must be left in the buffer untouched")
        }
    }

    @Test func decodesSeveralEventsFromOneRead() throws {
        var buffer = frame(type: "describe", data: nil, payload: nil)
        buffer.append(frame(type: "audio-stop", data: nil, payload: nil))

        let firstDecoded = try WyomingEventCodec.decode(from: &buffer)
        let secondDecoded = try WyomingEventCodec.decode(from: &buffer)
        let remaining = try WyomingEventCodec.decode(from: &buffer)

        let first = try #require(firstDecoded)
        let second = try #require(secondDecoded)

        #expect(first.kind == .describe)
        #expect(second.kind == .audioStop)
        #expect(remaining == nil)
    }

    /// Older senders put the data object straight into the header line instead of announcing a
    /// `data_length`, and the reference reader still accepts it.
    @Test func decodesDataInlineInTheHeader() throws {
        var buffer = Data(#"{"type":"synthesize","data":{"text":"Hello"}}"#.utf8)
        buffer.append(0x0A)

        let decoded = try WyomingEventCodec.decode(from: &buffer)
        let event = try #require(decoded)

        struct Synthesize: Decodable { let text: String }
        let synthesize = try event.decodeData(Synthesize.self)
        #expect(synthesize.text == "Hello")
    }

    @Test func encodesTheHeaderWithSnakeCasedLengths() throws {
        let event = WyomingEvent(kind: .transcript, data: Data(#"{"text":"hi"}"#.utf8), payload: Data([7]))

        let encoded = try WyomingEventCodec.encode(event)
        let newline = try #require(encoded.firstIndex(of: 0x0A))
        let json = try JSONSerialization.jsonObject(with: Data(encoded[encoded.startIndex ..< newline]))
        let header = try #require(json as? [String: Any])

        #expect(header["type"] as? String == "transcript")
        #expect(header["data_length"] as? Int == 13)
        #expect(header["payload_length"] as? Int == 1)
    }

    @Test func roundTripsWhatItEncodes() throws {
        let format = WyomingAudioFormat(rate: 22050, width: 2, channels: 1)
        var buffer = try WyomingEventCodec.encode(
            WyomingEvent(kind: .audioStart, encoding: format)
        )

        let decoded = try WyomingEventCodec.decode(from: &buffer)
        let event = try #require(decoded)

        let decodedFormat = try event.decodeData(WyomingAudioFormat.self)

        #expect(event.kind == .audioStart)
        #expect(decodedFormat == format)
    }

    /// The listener accepts connections from anything on the local network, so a peer that never
    /// sends a newline must fail rather than grow the buffer without limit.
    @Test func rejectsAHeaderWithoutAnEnd() {
        var buffer = Data(repeating: UInt8(ascii: "a"), count: 65 * 1024)

        #expect(throws: WyomingProtocolError.eventTooLarge) {
            _ = try WyomingEventCodec.decode(from: &buffer)
        }
    }

    @Test func rejectsAnOverlargeBody() {
        var buffer = Data(#"{"type":"audio-chunk","payload_length":999999999}"#.utf8)
        buffer.append(0x0A)

        #expect(throws: WyomingProtocolError.eventTooLarge) {
            _ = try WyomingEventCodec.decode(from: &buffer)
        }
    }

    @Test func rejectsALineThatIsNotAnEvent() {
        var buffer = Data("not json\n".utf8)

        #expect(throws: WyomingProtocolError.malformedEvent) {
            _ = try WyomingEventCodec.decode(from: &buffer)
        }
    }
}
