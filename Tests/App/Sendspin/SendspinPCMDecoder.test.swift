import Foundation
@testable import HomeAssistant
import Testing

struct SendspinPCMDecoderTests {
    private func format(bitDepth: Int) -> SendspinAudioFormat {
        SendspinAudioFormat(codec: .pcm, channels: 2, sampleRate: 48_000, bitDepth: bitDepth)
    }

    @Test func decodesSixteenBitLittleEndianSamples() throws {
        // -32768, 0, 32767 as little-endian signed 16-bit.
        let data = Data([0x00, 0x80, 0x00, 0x00, 0xFF, 0x7F])
        let samples = try #require(SendspinPCMDecoder.decode(data, format: format(bitDepth: 16)))
        #expect(samples.count == 3)
        #expect(samples[0] == -1)
        #expect(samples[1] == 0)
        #expect(abs(samples[2] - 1) < 0.0001)
    }

    @Test func decodesTwentyFourBitSamplesPackedInThreeBytes() throws {
        // -8388608 and 8388607.
        let data = Data([0x00, 0x00, 0x80, 0xFF, 0xFF, 0x7F])
        let samples = try #require(SendspinPCMDecoder.decode(data, format: format(bitDepth: 24)))
        #expect(samples.count == 2)
        #expect(samples[0] == -1)
        #expect(abs(samples[1] - 1) < 0.0001)
    }

    @Test func decodesThirtyTwoBitSamples() throws {
        let data = Data([0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00])
        let samples = try #require(SendspinPCMDecoder.decode(data, format: format(bitDepth: 32)))
        #expect(samples == [-1, 0])
    }

    @Test func rejectsPartialFramesAndUnknownDepths() {
        #expect(SendspinPCMDecoder.decode(Data([0x01]), format: format(bitDepth: 16)) == nil)
        #expect(SendspinPCMDecoder.decode(Data([0x01]), format: format(bitDepth: 8)) == nil)
    }
}
