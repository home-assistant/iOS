import Foundation

/// Decoded audio waiting to be played, and the logic that keeps it on the server's timeline.
///
/// This is the specification's suggested correction strategy. Each render cycle compares where the
/// read position is with where the time filter says playback should be. Small errors are absorbed
/// by dropping or repeating a single frame, inaudibly; anything past a millisecond, and every
/// start, is fixed in one step by skipping ahead or waiting in silence.
///
/// A value type with no locking of its own: the audio output guards it.
struct SendspinPlaybackBuffer {
    struct Chunk {
        /// Server time, in microseconds, of the first frame.
        let timestamp: Int64
        /// Interleaved samples.
        let samples: [Float]
        let frameCount: Int
    }

    enum RenderOutcome: Equatable {
        /// Nothing to play yet, or the first chunk is still in the future.
        case waiting
        case playing
        /// The buffer ran dry mid-cycle; the next cycle starts over with a snap.
        case underrun
    }

    private enum Constants {
        /// Below this, the position is left alone.
        static let deadBandMicroseconds = 100.0
        /// Past this, the position is snapped instead of corrected a frame at a time.
        static let snapThresholdMicroseconds = 1000.0
        /// One correction step lasts about this long whatever the sample rate.
        static let stepMicroseconds = 21.0
        /// The cap on how far one cycle's correction may bend playback speed.
        static let maximumSpeedDeviation = 0.005
    }

    let sampleRate: Double
    let channels: Int

    private var chunks: [Chunk] = []
    private var readFrame = 0
    private var isSynchronized = false

    init(sampleRate: Double, channels: Int) {
        self.sampleRate = sampleRate
        self.channels = channels
    }

    var isEmpty: Bool { chunks.isEmpty }

    /// Server time at which the buffered audio runs out.
    var bufferedUntil: Int64? {
        guard let last = chunks.last else { return nil }
        return last.timestamp + duration(frames: last.frameCount)
    }

    mutating func append(timestamp: Int64, samples: [Float]) {
        let frameCount = samples.count / max(channels, 1)
        guard frameCount > 0 else { return }
        chunks.append(Chunk(timestamp: timestamp, samples: samples, frameCount: frameCount))
    }

    mutating func clear() {
        chunks.removeAll()
        readFrame = 0
        isSynchronized = false
    }

    /// Fills `frameCount` frames for each channel.
    ///
    /// - Parameters:
    ///   - output: One buffer per channel, each at least `frameCount` long.
    ///   - targetServerTime: The server time, in microseconds, that the first frame of this cycle
    ///     should be heard at.
    mutating func render(
        into output: [UnsafeMutablePointer<Float>],
        frameCount: Int,
        targetServerTime: Double
    ) -> RenderOutcome {
        var written = 0

        if isSynchronized, let cursor = cursorServerTime {
            let error = cursor - targetServerTime
            if abs(error) > Constants.snapThresholdMicroseconds {
                isSynchronized = false
            } else if abs(error) > Constants.deadBandMicroseconds {
                let step = max(1, Int((Constants.stepMicroseconds * sampleRate / 1_000_000).rounded()))
                let limit = Int(Constants.maximumSpeedDeviation * Double(frameCount))
                let correction = min(step, limit)
                if correction > 0 {
                    if error < 0 {
                        // Late: drop frames to catch up.
                        advance(by: correction)
                    } else {
                        // Early: repeat the next frame to wait.
                        written = repeatNextFrame(into: output, count: correction)
                    }
                }
            }
        } else {
            isSynchronized = false
        }

        if !isSynchronized {
            switch snap(to: targetServerTime, frameCount: frameCount) {
            case .none:
                silence(output, from: 0, to: frameCount)
                return .waiting
            case let .some(leadingSilence):
                silence(output, from: 0, to: leadingSilence)
                written = leadingSilence
                isSynchronized = true
            }
        }

        written = copyFrames(into: output, from: written, to: frameCount)
        if written < frameCount {
            silence(output, from: written, to: frameCount)
            isSynchronized = false
            return .underrun
        }
        return .playing
    }

    // MARK: - Positioning

    private var cursorServerTime: Double? {
        guard let chunk = chunks.first else { return nil }
        return Double(chunk.timestamp) + Double(readFrame) * 1_000_000 / sampleRate
    }

    private func duration(frames: Int) -> Int64 {
        Int64((Double(frames) * 1_000_000 / sampleRate).rounded())
    }

    /// Positions the read cursor on the frame due at `target`. Returns how many frames of silence
    /// come first when the audio starts later in this cycle, or `nil` when nothing in the buffer
    /// plays within it.
    private mutating func snap(to target: Double, frameCount: Int) -> Int? {
        while let first = chunks.first, Double(first.timestamp + duration(frames: first.frameCount)) <= target {
            chunks.removeFirst()
        }
        readFrame = 0
        guard let first = chunks.first else { return nil }

        let offset = (target - Double(first.timestamp)) * sampleRate / 1_000_000
        if offset >= 0 {
            readFrame = min(Int(offset.rounded()), first.frameCount - 1)
            return 0
        }
        let lead = Int((-offset).rounded())
        return lead < frameCount ? lead : nil
    }

    private mutating func advance(by frames: Int) {
        var remaining = frames
        while remaining > 0, let first = chunks.first {
            let available = first.frameCount - readFrame
            if remaining < available {
                readFrame += remaining
                return
            }
            remaining -= available
            chunks.removeFirst()
            readFrame = 0
        }
    }

    // MARK: - Copying

    private func repeatNextFrame(into output: [UnsafeMutablePointer<Float>], count: Int) -> Int {
        guard let first = chunks.first else { return 0 }
        let base = readFrame * channels
        for frame in 0 ..< count {
            for (channel, buffer) in output.enumerated() {
                buffer[frame] = first.samples[base + min(channel, channels - 1)]
            }
        }
        return count
    }

    private mutating func copyFrames(into output: [UnsafeMutablePointer<Float>], from start: Int, to end: Int) -> Int {
        var position = start
        while position < end, let first = chunks.first {
            let count = min(end - position, first.frameCount - readFrame)
            for frame in 0 ..< count {
                let base = (readFrame + frame) * channels
                for (channel, buffer) in output.enumerated() {
                    buffer[position + frame] = first.samples[base + min(channel, channels - 1)]
                }
            }
            position += count
            readFrame += count
            if readFrame >= first.frameCount {
                chunks.removeFirst()
                readFrame = 0
            }
        }
        return position
    }

    private func silence(_ output: [UnsafeMutablePointer<Float>], from start: Int, to end: Int) {
        guard end > start else { return }
        for buffer in output {
            (buffer + start).update(repeating: 0, count: end - start)
        }
    }
}
