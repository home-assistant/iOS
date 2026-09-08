import AVFoundation
import Foundation
@testable import HomeAssistant
import Testing

struct WyomingPCMConverterTests {
    private func pcm(_ samples: [Int16]) -> Data {
        samples.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    @Test func convertsWholeFramesToTheRecognizerFormat() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 1))

        let buffer = try #require(converter.convert(pcm([0, 1000, -1000, 32767])))

        #expect(buffer.frameLength == 4)
        #expect(buffer.format.sampleRate == 16000)
        #expect(buffer.format.channelCount == 1)
        #expect(buffer.format.commonFormat == .pcmFormatFloat32)
    }

    /// Samples have to survive the integer-to-float conversion, or the recogniser is handed noise
    /// that happens to be the right length.
    @Test func preservesTheSampleValues() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 1))

        let buffer = try #require(converter.convert(pcm([0, 16384, -16384])))
        let channel = try #require(buffer.floatChannelData)

        #expect(abs(channel[0][0]) < 0.01)
        #expect(abs(channel[0][1] - 0.5) < 0.01)
        #expect(abs(channel[0][2] + 0.5) < 0.01)
    }

    /// Nothing in the protocol promises a chunk ends on a frame boundary, and a half frame carried
    /// into the next chunk would shift every following sample by a byte.
    @Test func carriesAPartialFrameIntoTheNextChunk() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 1))
        let samples = pcm([1000, 2000])

        // One byte short of a whole frame: nothing to convert yet.
        #expect(converter.convert(samples.prefix(3)) == nil)

        let buffer = try #require(converter.convert(samples.dropFirst(3)))
        let channel = try #require(buffer.floatChannelData)

        #expect(buffer.frameLength == 2)
        #expect(abs(channel[0][0] - Float(1000) / Float(Int16.max)) < 0.01)
        #expect(abs(channel[0][1] - Float(2000) / Float(Int16.max)) < 0.01)
    }

    @Test func waitsUntilThereIsAWholeFrame() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 1))

        #expect(converter.convert(Data()) == nil)
        #expect(converter.convert(Data([0x01])) == nil)
    }

    /// Home Assistant records in mono, but a client is free to send stereo; the recogniser only
    /// takes one channel.
    @Test func downmixesStereoToMono() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 2))

        let buffer = try #require(converter.convert(pcm([1000, 1000, 2000, 2000])))

        #expect(buffer.frameLength == 2)
        #expect(buffer.format.channelCount == 1)
    }

    @Test func keepsTheClientsSampleRateRatherThanResampling() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 22050, width: 2, channels: 1))

        let buffer = try #require(converter.convert(pcm([0, 1000])))

        #expect(converter.outputFormat.sampleRate == 22050)
        #expect(buffer.frameLength == 2)
    }

    /// Only 16-bit PCM is accepted; `width` is a byte count, so anything else is refused rather
    /// than guessed at.
    @Test func refusesAudioThatIsNot16Bit() {
        #expect(throws: WyomingProtocolError.self) {
            _ = try WyomingPCMConverter(format: .init(rate: 16000, width: 4, channels: 1))
        }
        #expect(throws: WyomingProtocolError.self) {
            _ = try WyomingPCMConverter(format: .init(rate: 16000, width: 1, channels: 1))
        }
    }

    @Test func refusesAFormatWithNoRateOrChannels() {
        #expect(throws: WyomingProtocolError.self) {
            _ = try WyomingPCMConverter(format: .init(rate: 0, width: 2, channels: 1))
        }
        #expect(throws: WyomingProtocolError.self) {
            _ = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 0))
        }
    }
}
