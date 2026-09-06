import AudioToolbox
import AVFoundation
import Darwin
import Foundation
import os

/// Renders the server's audio timeline onto this device's audio clock.
///
/// Chunks carry the server time their first sample must leave the audio port at, so the render
/// thread does not play them back to back: on every block it asks the clock filter where each chunk
/// belongs in local time and writes it there. Small residual errors are absorbed by dropping or
/// repeating a few frames — the protocol's suggested correction strategy, which stays inaudible
/// because a step is a handful of samples — and anything past a millisecond is snapped in one shot
/// rather than warbled towards.
final class SendspinAudioRenderer {
    enum RendererError: Error {
        case unsupportedFormat
    }

    /// Below this the timing error is left alone; correcting inaudible error only adds artefacts.
    private static let deadBandMicroseconds: Double = 100
    /// Past this the error is snapped in one step instead of corrected smoothly.
    private static let oneShotThresholdMicroseconds: Double = 1_000
    /// A correction may not exceed 0.5% of a chunk, the specification's speed deviation cap.
    private static let maximumCorrectionFraction: Double = 0.005
    private static let gainRampSeconds: Double = 0.02

    /// What the render loop does with the head chunk on this pass.
    private enum Correction {
        /// Nothing is due before the block ends.
        case waitForNextBlock
        /// Leave this many frames silent, because the chunk is due later than the current slot.
        case skip(Int)
        /// Discard this many frames from the chunk, because its moment has passed.
        case drop(Int)
        case play
    }

    /// One decoded chunk waiting for its moment on the timeline.
    private struct QueuedChunk {
        let startServerMicroseconds: Int64
        let samples: [Float]
        let frameCount: Int
        var consumedFrames: Int
    }

    private let engine = AVAudioEngine()
    private let lock: UnsafeMutablePointer<os_unfair_lock> = {
        let pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        pointer.initialize(to: os_unfair_lock())
        return pointer
    }()

    private var sourceNode: AVAudioSourceNode?

    // Everything below is guarded by `lock`.
    private var queue: [QueuedChunk] = []
    /// Chunks the render thread has finished with. Draining them on the main thread keeps
    /// deallocation off the audio thread.
    private var retired: [QueuedChunk] = []
    private var clock: SendspinClockSnapshot?
    private var outputDelayMicroseconds: Double = 0
    private var outputLatencyMicroseconds: Double = 0
    private var currentGain: Float = 1
    private var targetGain: Float = 1
    private var queuedFrames = 0
    private var underruns = 0
    private var lastCorrectionMicroseconds: Double = 0

    init() {
        queue.reserveCapacity(256)
        retired.reserveCapacity(256)
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    func start(format: SendspinAudioFormat) throws {
        stop()
        guard
            format.codec == .pcm,
            let audioFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(format.sampleRate),
                channels: AVAudioChannelCount(format.channels),
                interleaved: false
            )
        else {
            throw RendererError.unsupportedFormat
        }

        let channels = format.channels
        let sampleRate = Double(format.sampleRate)
        let node = AVAudioSourceNode(format: audioFormat) { [weak self] isSilence, timestamp, frameCount, buffers in
            let list = UnsafeMutableAudioBufferListPointer(buffers)
            for buffer in list where buffer.mData != nil {
                memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }
            guard let self else {
                isSilence.pointee = ObjCBool(true)
                return noErr
            }
            let wrote = self.render(
                into: list,
                frameCount: Int(frameCount),
                timestamp: timestamp.pointee,
                channels: channels,
                sampleRate: sampleRate
            )
            isSilence.pointee = ObjCBool(!wrote)
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: audioFormat)
        sourceNode = node
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.stop()
        if let sourceNode {
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
        }
        sourceNode = nil
        clearBuffers()
    }

    /// Restarts the engine after an interruption or route change without disturbing the queue.
    func resume() throws {
        guard sourceNode != nil, !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
    }

    func enqueue(startServerMicroseconds: Int64, samples: [Float], channels: Int) {
        guard channels > 0 else { return }
        let chunk = QueuedChunk(
            startServerMicroseconds: startServerMicroseconds,
            samples: samples,
            frameCount: samples.count / channels,
            consumedFrames: 0
        )
        withLock {
            queue.append(chunk)
            queuedFrames += chunk.frameCount
        }
    }

    /// `stream/clear` semantics: drop everything buffered and continue with what arrives next.
    func clearBuffers() {
        withLock {
            queue.removeAll(keepingCapacity: true)
            retired.removeAll(keepingCapacity: true)
            queuedFrames = 0
        }
    }

    func setClock(_ snapshot: SendspinClockSnapshot?) {
        withLock { clock = snapshot }
    }

    func setOutputDelay(milliseconds: Int) {
        withLock { outputDelayMicroseconds = Double(milliseconds) * 1_000 }
    }

    /// Volume is perceived loudness, so the linear gain the samples are scaled by is `(v/100)^1.5`.
    func setVolume(_ volume: Int, muted: Bool) {
        let clamped = min(max(volume, 0), 100)
        let gain = muted ? 0 : Float(pow(Double(clamped) / 100, 1.5))
        withLock { targetGain = gain }
    }

    /// The render timestamp is when the block reaches the engine, not the speaker.
    func setOutputLatency(seconds: TimeInterval) {
        withLock { outputLatencyMicroseconds = seconds * 1_000_000 }
    }

    func statistics(sampleRate: Int) -> SendspinRendererStatistics {
        var frames = 0
        var chunks = 0
        var underrunCount = 0
        var correction: Double = 0
        withLock {
            frames = queuedFrames
            chunks = queue.count
            underrunCount = underruns
            correction = lastCorrectionMicroseconds
            retired.removeAll(keepingCapacity: true)
        }
        let milliseconds = sampleRate > 0 ? frames * 1_000 / sampleRate : 0
        return SendspinRendererStatistics(
            bufferedMilliseconds: milliseconds,
            queuedChunks: chunks,
            underruns: underrunCount,
            lastCorrectionMicroseconds: correction
        )
    }

    private func withLock(_ body: () -> Void) {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        body()
    }

    // MARK: - Render thread

    private func render(
        into buffers: UnsafeMutableAudioBufferListPointer,
        frameCount: Int,
        timestamp: AudioTimeStamp,
        channels: Int,
        sampleRate: Double
    ) -> Bool {
        // The producer only ever holds the lock long enough to append; on the rare miss, silence is
        // better than blocking the audio thread.
        guard os_unfair_lock_trylock(lock) else { return false }
        defer { os_unfair_lock_unlock(lock) }
        guard let clock else { return false }

        let hostTime = timestamp.mFlags.contains(.hostTimeValid) ? timestamp.mHostTime : mach_absolute_time()
        let blockStart = Double(SendspinMonotonicClock.microseconds(fromHostTime: hostTime)) + outputLatencyMicroseconds
        let microsecondsPerFrame = 1_000_000 / sampleRate

        var writeIndex = 0
        var wroteAnything = false
        var didCorrect = false

        while writeIndex < frameCount, let head = queue.first {
            let slotTime = blockStart + Double(writeIndex) * microsecondsPerFrame
            let scheduled = clock
                .localTime(forServer: Double(head.startServerMicroseconds) - outputDelayMicroseconds)
                + Double(head.consumedFrames) * microsecondsPerFrame
            let error = scheduled - slotTime

            switch correction(
                forError: error,
                remainingFrames: frameCount - writeIndex,
                chunkFrames: head.frameCount,
                microsecondsPerFrame: microsecondsPerFrame,
                isCorrectionAllowed: !didCorrect
            ) {
            case .waitForNextBlock:
                return wroteAnything
            case let .skip(frames):
                lastCorrectionMicroseconds = error
                didCorrect = true
                writeIndex += frames
            case let .drop(frames):
                lastCorrectionMicroseconds = error
                didCorrect = true
                consume(frames: frames)
            case .play:
                let framesToCopy = min(head.frameCount - head.consumedFrames, frameCount - writeIndex)
                copy(
                    head,
                    framesToCopy: framesToCopy,
                    writeIndex: writeIndex,
                    into: buffers,
                    channels: channels,
                    sampleRate: sampleRate
                )
                writeIndex += framesToCopy
                consume(frames: framesToCopy)
                wroteAnything = wroteAnything || framesToCopy > 0
            }
        }

        if queue.isEmpty, wroteAnything, writeIndex < frameCount {
            underruns += 1
        }
        return wroteAnything
    }

    /// What to do with the head chunk given how far its scheduled moment is from the slot the
    /// renderer has reached. Positive error means the chunk is due later than the slot.
    private func correction(
        forError error: Double,
        remainingFrames: Int,
        chunkFrames: Int,
        microsecondsPerFrame: Double,
        isCorrectionAllowed: Bool
    ) -> Correction {
        guard error < Double(remainingFrames) * microsecondsPerFrame else { return .waitForNextBlock }
        guard isCorrectionAllowed, abs(error) > Self.deadBandMicroseconds else { return .play }

        // Past the one-shot threshold the error is too large to hide in a few frames, so it is
        // corrected in a single deliberate step instead of being warbled towards.
        let frames: Int
        if abs(error) > Self.oneShotThresholdMicroseconds {
            frames = Int(abs(error) / microsecondsPerFrame)
        } else {
            frames = correctionFrames(
                forError: abs(error),
                chunkFrames: chunkFrames,
                microsecondsPerFrame: microsecondsPerFrame
            )
        }
        guard frames > 0 else { return .play }
        return error > 0 ? .skip(frames) : .drop(frames)
    }

    /// The smallest step that keeps up with the error, capped so a single chunk never bends
    /// playback speed by more than half a percent.
    private func correctionFrames(forError error: Double, chunkFrames: Int, microsecondsPerFrame: Double) -> Int {
        let needed = Int((error / microsecondsPerFrame).rounded())
        let cap = max(1, Int(Double(chunkFrames) * Self.maximumCorrectionFraction))
        return max(1, min(needed, cap))
    }

    private func consume(frames: Int) {
        guard !queue.isEmpty else { return }
        var remaining = frames
        while !queue.isEmpty {
            let available = queue[0].frameCount - queue[0].consumedFrames
            if remaining < available {
                queue[0].consumedFrames += remaining
                queuedFrames -= remaining
                return
            }
            remaining -= available
            queuedFrames -= available
            retired.append(queue.removeFirst())
            if remaining == 0 { return }
        }
    }

    private func copy(
        _ chunk: QueuedChunk,
        framesToCopy: Int,
        writeIndex: Int,
        into buffers: UnsafeMutableAudioBufferListPointer,
        channels: Int,
        sampleRate: Double
    ) {
        let rampFrames = max(1.0, sampleRate * Self.gainRampSeconds)
        let step = (targetGain - currentGain) / Float(rampFrames)
        let sourceOffset = chunk.consumedFrames * channels

        for channel in 0 ..< channels {
            guard channel < buffers.count, let raw = buffers[channel].mData else { continue }
            let destination = raw.assumingMemoryBound(to: Float.self)
            for frame in 0 ..< framesToCopy {
                let sample = chunk.samples[sourceOffset + frame * channels + channel]
                destination[writeIndex + frame] = sample * gain(atFrame: frame, step: step)
            }
        }

        currentGain = gain(atFrame: framesToCopy - 1, step: step)
    }

    private func gain(atFrame frame: Int, step: Float) -> Float {
        let value = currentGain + step * Float(frame + 1)
        return step >= 0 ? min(value, targetGain) : max(value, targetGain)
    }
}
