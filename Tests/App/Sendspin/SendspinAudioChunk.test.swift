import Foundation
@testable import HomeAssistant
import Testing

struct SendspinAudioChunkTests {
    @Test func parsesBigEndianHeaderAndPayload() throws {
        var payload = Data([0, 0, 0, 0, 0, 0x0F, 0x42, 0x40])
        payload.append(contentsOf: [0, 0, 0x03, 0xE8])
        payload.append(contentsOf: [0x11, 0x22])
        let chunk = try #require(SendspinAudioChunk(payload: payload))
        #expect(chunk.serverTimestamp == 1_000_000)
        #expect(chunk.sendAhead == 1_000)
        #expect(chunk.data == Data([0x11, 0x22]))
        #expect(chunk.hasMeasurableLead)
    }

    /// Both saturation values mean "no lead measured", so neither may be used as a delay sample.
    @Test func treatsSaturatedLeadAsUnmeasured() throws {
        var zeroLead = Data(repeating: 0, count: 12)
        zeroLead.append(0x01)
        #expect(try #require(SendspinAudioChunk(payload: zeroLead)).hasMeasurableLead == false)

        var maximumLead = Data(repeating: 0, count: 8)
        maximumLead.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])
        maximumLead.append(0x01)
        #expect(try #require(SendspinAudioChunk(payload: maximumLead)).hasMeasurableLead == false)
    }

    @Test func rejectsAHeaderWithNoAudio() {
        #expect(SendspinAudioChunk(payload: Data(repeating: 0, count: 12)) == nil)
    }
}
