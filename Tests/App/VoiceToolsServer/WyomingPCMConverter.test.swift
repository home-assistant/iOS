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

        let converted = converter.convert(pcm([0, 1000, -1000, 32767]))
        let buffer = try #require(converted)

        #expect(buffer.frameLength == 4)
        #expect(buffer.format.sampleRate == 16000)
        #expect(buffer.format.channelCount == 1)
        #expect(buffer.format.commonFormat == .pcmFormatFloat32)
    }

    /// Samples have to survive the integer-to-float conversion, or the recogniser is handed noise
    /// that happens to be the right length.
    @Test func preservesTheSampleValues() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 1))

        let converted = converter.convert(pcm([0, 16384, -16384]))
        let buffer = try #require(converted)
        let channel = try #require(buffer.floatChannelData)

        #expect(abs(channel[0][0]) < 0.01)
        #expect(abs(channel[0][1] - 0.5) < 0.01)
        #expect(abs(channel[0][2] + 0.5) < 0.01)
    }

    /// Nothing in the protocol promises a chunk ends on a frame boundary, and half a frame carried
    /// into the next chunk would shift every following sample by a byte.
    @Test func carriesAPartialFrameIntoTheNextChunk() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 1))
        let samples = pcm([1000, 2000])

        // Three bytes is one whole frame plus half of the next: the whole one converts, the half
        // is held back.
        let firstConverted = converter.convert(samples.prefix(3))
        let first = try #require(firstConverted)
        #expect(first.frameLength == 1)

        // The byte held back completes the second frame once the rest of it arrives.
        let secondConverted = converter.convert(samples.dropFirst(3))
        let second = try #require(secondConverted)
        #expect(second.frameLength == 1)

        // Both samples survive the split, which is the whole point of holding the odd byte.
        let firstChannel = try #require(first.floatChannelData)
        let secondChannel = try #require(second.floatChannelData)
        #expect(abs(firstChannel[0][0] - Float(1000) / Float(Int16.max)) < 0.01)
        #expect(abs(secondChannel[0][0] - Float(2000) / Float(Int16.max)) < 0.01)
    }

    @Test func waitsUntilThereIsAWholeFrame() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 1))

        let empty = converter.convert(Data())
        let singleByte = converter.convert(Data([0x01]))

        #expect(empty == nil)
        #expect(singleByte == nil)
    }

    /// Home Assistant records in mono, but a client is free to send stereo; the recogniser only
    /// takes one channel.
    @Test func downmixesStereoToMono() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 16000, width: 2, channels: 2))

        let converted = converter.convert(pcm([1000, 1000, 2000, 2000]))
        let buffer = try #require(converted)

        #expect(buffer.frameLength == 2)
        #expect(buffer.format.channelCount == 1)
    }

    @Test func keepsTheClientsSampleRateRatherThanResampling() throws {
        var converter = try WyomingPCMConverter(format: .init(rate: 22050, width: 2, channels: 1))

        let converted = converter.convert(pcm([0, 1000]))
        let buffer = try #require(converted)

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
