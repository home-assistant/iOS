import AVFoundation
@testable import HomeAssistant
import XCTest

final class AssistAudioConverterTests: XCTestCase {
    func testStereoCaptureKeepsDurationAndMixesBothChannels() throws {
        let converter = AssistAudioConverter()
        // Native downmix gain differs between iOS and macOS. Equal, opposite channels
        // must cancel on both platforms, which also detects dropping either channel.
        let input = try makeBuffer(rate: 16000, channels: 2, frames: 1600) { _, channel in
            channel == 0 ? 0.25 : -0.25
        }
        let samples = try convert(converter, input)

        // Raw stereo bytes treated as mono would contain 3200 samples and play at half speed.
        XCTAssertEqual(samples.count, 1600)
        XCTAssertTrue(samples.allSatisfy { abs(Int($0)) <= 1 })
    }

    func testSpeechOnRightChannelIsNotDiscarded() throws {
        let input = try makeBuffer(rate: 16000, channels: 2, frames: 1600) { frame, channel in
            channel == 0 ? 0 : Float(sin(2 * .pi * 1000 * Double(frame) / 16000)) * 0.5
        }
        let samples = try convert(AssistAudioConverter(), input)

        XCTAssertEqual(samples.count, 1600)
        XCTAssertGreaterThan(samples.map { abs(Int($0)) }.max() ?? 0, 7000)
        XCTAssertEqual(positiveCrossings(samples), 100, accuracy: 1)
    }

    func testMonoPCMRemainsBitExact() throws {
        let input = try makeBuffer(rate: 16000, channels: 1, frames: 4096) { frame, _ in
            Float((frame % 8) - 4) / 8
        }
        let samples = try convert(AssistAudioConverter(), input)
        let expected = (0 ..< 4096).map { Int16((($0 % 8) - 4) * 4096) }

        XCTAssertEqual(samples, expected)
    }

    func testNonInterleavedFloatStereoIsConvertedToInt16Mono() throws {
        let input = try makeBuffer(
            rate: 16000, channels: 2, frames: 1600, format: .pcmFormatFloat32, interleaved: false
        ) { _, channel in channel == 0 ? -0.75 : 0.25 }
        let samples = try convert(AssistAudioConverter(), input)

        XCTAssertEqual(samples.count, 1600)
        XCTAssertTrue(samples.allSatisfy { abs(Int($0) + 8192) <= 1 })
    }

    func testDeviceSampleRatesPreserveDurationAndPitchAcrossChunks() throws {
        for rate in [24000.0, 44100.0, 48000.0] {
            let converter = AssistAudioConverter()
            let frameCount = Int(rate / 10)
            var samples = [Int16]()
            for offset in stride(from: 0, to: frameCount, by: 127) {
                let input = try makeBuffer(rate: rate, channels: 2, frames: min(127, frameCount - offset)) { frame, _ in
                    Float(sin(2 * .pi * 1000 * Double(frame + offset) / rate)) * 0.5
                }
                samples += try convert(converter, input)
            }

            XCTAssertEqual(samples.count, 1600, accuracy: 1, "Input rate: \(rate)")
            XCTAssertEqual(positiveCrossings(samples), 100, accuracy: 1, "Input rate: \(rate)")
        }
    }

    func testStereoSilenceStaysSilent() throws {
        let input = try makeBuffer(rate: 16000, channels: 2, frames: 1600) { _, _ in 0 }
        let samples = try convert(AssistAudioConverter(), input)

        XCTAssertEqual(samples.count, 1600)
        XCTAssertTrue(samples.allSatisfy { $0 == 0 })
    }

    func testLargeCaptureBuffersPreserveDurationAndPitch() throws {
        // Each buffer converts to more frames than one output chunk holds.
        for format in [AVAudioCommonFormat.pcmFormatInt16, .pcmFormatFloat32] {
            for rate in [24000.0, 44100.0, 48000.0] {
                let converter = AssistAudioConverter()
                let frames = Int(rate / 5)
                var samples = [Int16]()
                for chunk in 0 ..< 4 {
                    let input = try makeBuffer(
                        rate: rate, channels: 2, frames: frames,
                        format: format, interleaved: format == .pcmFormatInt16
                    ) { frame, channel in
                        channel == 0 ? 0 : Float(sin(2 * .pi * 1000 * Double(chunk * frames + frame) / rate)) * 0.5
                    }
                    let converted = try convert(converter, input)
                    XCTAssertEqual(converted.count, 3200, accuracy: 1)
                    samples += converted
                }
                XCTAssertEqual(samples.count, 12800, accuracy: 1)
                XCTAssertEqual(positiveCrossings(samples), 800, accuracy: 1)
            }
        }
    }

    func testInputFormatChangeRecreatesConverter() throws {
        let converter = AssistAudioConverter()
        let stereo = try makeBuffer(rate: 16000, channels: 2, frames: 1600) { _, _ in 0.5 }
        let mono = try makeBuffer(rate: 16000, channels: 1, frames: 1600) { _, _ in -0.25 }

        let stereoSamples = try convert(converter, stereo)
        let monoSamples = try convert(converter, mono)
        XCTAssertEqual(stereoSamples.count, 1600)
        XCTAssertEqual(monoSamples.count, 1600)
        XCTAssertTrue(stereoSamples.allSatisfy { $0 > 0 })
        XCTAssertTrue(monoSamples.allSatisfy { $0 == -8192 })
    }

    func testMissingPCMDataIsRejected() throws {
        let input = try makeBuffer(rate: 16000, channels: 2, frames: 1600, includeData: false) { _, _ in 0 }
        XCTAssertThrowsError(try AssistAudioConverter().convert(input))
    }

    func testCaptureWithoutFormatIsRejected() throws {
        XCTAssertThrowsError(try AssistAudioConverter().convert(
            AssistAudioTestBuffers.makeUnformattedBuffer(frames: 1)
        ))
    }

    func testInvalidPCMFormatIsRejected() throws {
        // Core Media permits these descriptions even though they cannot describe a valid stream.
        for (rate, channels) in [(16000.0, UInt32(0)), (Double.nan, UInt32(1)), (Double.infinity, UInt32(1))] {
            var format = AudioStreamBasicDescription(
                mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 2 * channels, mFramesPerPacket: 1,
                mBytesPerFrame: 2 * channels, mChannelsPerFrame: channels,
                mBitsPerChannel: 16, mReserved: 0
            )
            var description: CMAudioFormatDescription?
            XCTAssertEqual(CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault, asbd: &format,
                layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
                extensions: nil, formatDescriptionOut: &description
            ), noErr)
            var buffer: CMSampleBuffer?
            XCTAssertEqual(try CMSampleBufferCreate(
                allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
                makeDataReadyCallback: nil, refcon: nil,
                formatDescription: XCTUnwrap(description), sampleCount: 1,
                sampleTimingEntryCount: 0, sampleTimingArray: nil,
                sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &buffer
            ), noErr)

            let input = try XCTUnwrap(buffer)
            XCTAssertThrowsError(try AssistAudioConverter().convert(input))
        }
    }

    private func convert(_ converter: AssistAudioConverter, _ input: CMSampleBuffer) throws -> [Int16] {
        try AssistAudioTestBuffers.samples(converter.convert(input))
    }

    private func positiveCrossings(_ samples: [Int16]) -> Int {
        AssistAudioTestBuffers.positiveCrossings(samples)
    }

    private func makeBuffer(
        rate: Double,
        channels: AVAudioChannelCount,
        frames: Int,
        format: AVAudioCommonFormat = .pcmFormatInt16,
        interleaved: Bool = true,
        includeData: Bool = true,
        sample: (Int, Int) -> Float
    ) throws -> CMSampleBuffer {
        try AssistAudioTestBuffers.makeBuffer(
            rate: rate, channels: channels, frames: frames, format: format,
            interleaved: interleaved, includeData: includeData, sample: sample
        )
    }
}
