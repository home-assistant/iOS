import Foundation
@testable import HomeAssistant
import Testing

struct SendspinPCMDecoderTests {
    @Test func decodesSixteenBitLittleEndian() throws {
        let samples = try SendspinPCMDecoder.decode(Data([0x00, 0x40, 0x00, 0xC0]), bitDepth: 16, channels: 2)
        #expect(samples == [0.5, -0.5])
    }

    @Test func decodesTwentyFourBitWithItsSign() throws {
        let samples = try SendspinPCMDecoder.decode(
            Data([0x00, 0x00, 0x40, 0x00, 0x00, 0xC0]),
            bitDepth: 24,
            channels: 1
        )
        #expect(samples == [0.5, -0.5])
    }

    @Test func decodesThirtyTwoBit() throws {
        let samples = try SendspinPCMDecoder.decode(Data([0x00, 0x00, 0x00, 0x40]), bitDepth: 32, channels: 1)
        #expect(samples == [0.5])
    }

    @Test func rejectsPartialFramesAndUnknownDepths() {
        #expect(throws: SendspinPCMDecoder.Failure.partialFrame) {
            try SendspinPCMDecoder.decode(Data([0, 0, 0]), bitDepth: 16, channels: 2)
        }
        #expect(throws: SendspinPCMDecoder.Failure.unsupportedBitDepth(8)) {
            try SendspinPCMDecoder.decode(Data([0]), bitDepth: 8, channels: 1)
        }
    }
}
