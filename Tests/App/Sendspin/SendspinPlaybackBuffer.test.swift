import Foundation
@testable import HomeAssistant
import Testing

/// Driven at 1 kHz so one frame is one millisecond and positions are easy to read.
struct SendspinPlaybackBufferTests {
    private static let rate = 1000.0

    /// A mono chunk whose samples count up from `first`, so the output shows which frames played.
    private func chunk(at milliseconds: Int64, frames: Int, first: Float) -> (Int64, [Float]) {
        (milliseconds * 1000, (0 ..< frames).map { first + Float($0) })
    }

    private func render(
        _ buffer: inout SendspinPlaybackBuffer,
        frames: Int,
        atMilliseconds milliseconds: Double
    ) -> ([Float], SendspinPlaybackBuffer.RenderOutcome) {
        var output = [Float](repeating: -1, count: frames)
        let outcome = output.withUnsafeMutableBufferPointer { pointer in
            buffer.render(into: [pointer.baseAddress!], frameCount: frames, targetServerTime: milliseconds * 1000)
        }
        return (output, outcome)
    }

    @Test func waitsInSilenceUntilTheFirstChunkIsDue() {
        var buffer = SendspinPlaybackBuffer(sampleRate: Self.rate, channels: 1)
        #expect(buffer.isEmpty)
        let (timestamp, samples) = chunk(at: 100, frames: 10, first: 1)
        buffer.append(timestamp: timestamp, samples: samples)
        #expect(buffer.bufferedUntil == 110_000)

        let (early, earlyOutcome) = render(&buffer, frames: 4, atMilliseconds: 50)
        #expect(earlyOutcome == .waiting)
        #expect(early == [0, 0, 0, 0])

        // The chunk starts two frames into this cycle.
        let (start, startOutcome) = render(&buffer, frames: 4, atMilliseconds: 98)
        #expect(startOutcome == .playing)
        #expect(start == [0, 0, 1, 2])

        let (next, _) = render(&buffer, frames: 4, atMilliseconds: 102)
        #expect(next == [3, 4, 5, 6])
    }

    /// Joining late skips straight to the frame that is due, and stale chunks are dropped.
    @Test func snapsIntoTheMiddleOfTheStream() {
        var buffer = SendspinPlaybackBuffer(sampleRate: Self.rate, channels: 1)
        for (timestamp, samples) in [chunk(at: 0, frames: 10, first: 0), chunk(at: 10, frames: 10, first: 10)] {
            buffer.append(timestamp: timestamp, samples: samples)
        }
        let (output, outcome) = render(&buffer, frames: 4, atMilliseconds: 13)
        #expect(outcome == .playing)
        #expect(output == [13, 14, 15, 16])
    }

    @Test func playsAcrossChunkBoundaries() {
        var buffer = SendspinPlaybackBuffer(sampleRate: Self.rate, channels: 1)
        for (timestamp, samples) in [chunk(at: 0, frames: 3, first: 0), chunk(at: 3, frames: 3, first: 3)] {
            buffer.append(timestamp: timestamp, samples: samples)
        }
        let (output, _) = render(&buffer, frames: 5, atMilliseconds: 0)
        #expect(output == [0, 1, 2, 3, 4])
    }

    /// Running out mid-cycle fills the rest with silence and starts over on the next cycle.
    @Test func reportsAnUnderrun() {
        var buffer = SendspinPlaybackBuffer(sampleRate: Self.rate, channels: 1)
        let (timestamp, samples) = chunk(at: 0, frames: 3, first: 1)
        buffer.append(timestamp: timestamp, samples: samples)
        let (output, outcome) = render(&buffer, frames: 5, atMilliseconds: 0)
        #expect(outcome == .underrun)
        #expect(output == [1, 2, 3, 0, 0])
    }

    @Test func clearingDropsEverything() {
        var buffer = SendspinPlaybackBuffer(sampleRate: Self.rate, channels: 1)
        let (timestamp, samples) = chunk(at: 0, frames: 10, first: 1)
        buffer.append(timestamp: timestamp, samples: samples)
        buffer.clear()
        #expect(buffer.isEmpty)
        #expect(buffer.bufferedUntil == nil)
        let (_, outcome) = render(&buffer, frames: 4, atMilliseconds: 0)
        #expect(outcome == .waiting)
    }

    /// At 48 kHz a small drift is absorbed one frame at a time rather than with a jump.
    @Test func correctsSmallErrorsOneFrameAtATime() {
        let rate = 48000.0
        var buffer = SendspinPlaybackBuffer(sampleRate: rate, channels: 1)
        buffer.append(timestamp: 0, samples: (0 ..< 4800).map { Float($0) })
        func render(frames: Int, at microseconds: Double) -> [Float] {
            var output = [Float](repeating: -1, count: frames)
            _ = output.withUnsafeMutableBufferPointer { pointer in
                buffer.render(into: [pointer.baseAddress!], frameCount: frames, targetServerTime: microseconds)
            }
            return output
        }
        let frameMicroseconds = 1_000_000 / rate
        #expect(render(frames: 480, at: 0).first == 0)

        // The clock now says playback should be 200 µs further along: late, so a frame is dropped.
        let late = render(frames: 480, at: 480 * frameMicroseconds + 200)
        #expect(late.first == 481)

        // And now 200 µs behind where the buffer is: early, so a frame is repeated.
        let early = render(frames: 480, at: 961 * frameMicroseconds - 400)
        #expect(early[0] == early[1])
    }

    /// Stereo frames are copied to their own channels, and a mono stream is spread across both.
    @Test func routesChannels() {
        var stereo = SendspinPlaybackBuffer(sampleRate: Self.rate, channels: 2)
        stereo.append(timestamp: 0, samples: [1, -1, 2, -2])
        var left = [Float](repeating: 0, count: 2)
        var right = [Float](repeating: 0, count: 2)
        left.withUnsafeMutableBufferPointer { leftPointer in
            right.withUnsafeMutableBufferPointer { rightPointer in
                _ = stereo.render(
                    into: [leftPointer.baseAddress!, rightPointer.baseAddress!],
                    frameCount: 2,
                    targetServerTime: 0
                )
            }
        }
        #expect(left == [1, 2])
        #expect(right == [-1, -2])
    }
}
