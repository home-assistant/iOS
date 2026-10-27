import AVFoundation
import XCTest

/// Builds capture-style sample buffers and measures converted audio for the Assist audio tests.
enum AssistAudioTestBuffers {
    static func makeBuffer(
        rate: Double,
        channels: AVAudioChannelCount,
        frames: Int,
        format: AVAudioCommonFormat = .pcmFormatInt16,
        interleaved: Bool = true,
        includeData: Bool = true,
        sample: (Int, Int) -> Float
    ) throws -> CMSampleBuffer {
        let audioFormat = try XCTUnwrap(AVAudioFormat(
            commonFormat: format, sampleRate: rate, channels: channels, interleaved: interleaved
        ))
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frames)))
        pcm.frameLength = pcm.frameCapacity
        for frame in 0 ..< frames {
            for channel in 0 ..< Int(channels) {
                let bufferIndex = interleaved ? 0 : channel
                let sampleIndex = interleaved ? frame * Int(channels) + channel : frame
                if format == .pcmFormatInt16 {
                    let value = max(-32768, min(32767, sample(frame, channel) * 32768))
                    pcm.int16ChannelData?[bufferIndex][sampleIndex] = Int16(value)
                } else {
                    pcm.floatChannelData?[bufferIndex][sampleIndex] = sample(frame, channel)
                }
            }
        }

        var buffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(rate)),
            presentationTimeStamp: .zero, decodeTimeStamp: .invalid
        )
        XCTAssertEqual(CMSampleBufferCreate(
            allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
            makeDataReadyCallback: nil, refcon: nil,
            formatDescription: audioFormat.formatDescription, sampleCount: frames,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &buffer
        ), noErr)
        let result = try XCTUnwrap(buffer)
        if includeData {
            XCTAssertEqual(CMSampleBufferSetDataBufferFromAudioBufferList(
                result, blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: 0, bufferList: pcm.audioBufferList
            ), noErr)
            XCTAssertEqual(CMSampleBufferSetDataReady(result), noErr)
        }
        return result
    }

    static func makeUnformattedBuffer(frames: Int) throws -> CMSampleBuffer {
        var buffer: CMSampleBuffer?
        XCTAssertEqual(CMSampleBufferCreate(
            allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: nil,
            sampleCount: frames, sampleTimingEntryCount: 0, sampleTimingArray: nil,
            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &buffer
        ), noErr)
        return try XCTUnwrap(buffer)
    }

    static func samples(_ data: Data) -> [Int16] {
        XCTAssertEqual(data.count % 2, 0)
        return data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
    }

    static func positiveCrossings(_ samples: [Int16]) -> Int {
        // Ignore tiny filter ringing around zero when measuring the resampled tone's pitch.
        var ready = true
        var count = 0
        for sample in samples {
            if sample < -1024 {
                ready = true
            } else if ready, sample > 1024 {
                count += 1
                ready = false
            }
        }
        return count
    }
}
