import AVFoundation
import Foundation
import os
import Shared

/// Plays a Sendspin stream through `AVAudioEngine`, in step with the server's timeline.
///
/// The engine pulls audio from a source node whose render block asks the playback buffer for
/// whatever is due at the moment that render cycle will be heard. Chunks are decoded on the
/// receiving thread, so the render thread only copies samples.
final class SendspinAudioOutput: SendspinAudioRendering, @unchecked Sendable {
    /// What the render thread reads, behind one lock that is only ever held for a copy.
    private struct RenderState {
        var buffer: SendspinPlaybackBuffer?
        var mapping = SendspinClockMapping()
        var outputDelayMicroseconds: Int64 = 0
        var outputLatencyMicroseconds: Int64 = 0
        var targetGain: Float = 1
        var currentGain: Float = 1
        var lastOutcome: SendspinPlaybackBuffer.RenderOutcome = .waiting
    }

    private let state = OSAllocatedUnfairLock(initialState: RenderState())
    private let engineLock = NSLock()
    private var engine: AVAudioEngine?
    private var engineFormat: SendspinStreamFormat?
    /// The format chunks are decoded with: the one in effect when each arrives.
    private var streamFormat: SendspinStreamFormat?
    private var observers: [NSObjectProtocol] = []

    /// Told when something outside Sendspin takes the audio hardware and when it gives it back.
    var onInterruption: (@Sendable (_ began: Bool) -> Void)?

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshOutputLatency()
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var isRunning: Bool {
        engineLock.withLock { engine?.isRunning ?? false }
    }

    // MARK: - Stream lifecycle

    /// Starts, or reconfigures, output for a stream. A format change that keeps the sample rate and
    /// channel count only changes how later chunks are decoded, so the timeline carries on.
    func start(format: SendspinStreamFormat) throws {
        streamFormat = format
        try engineLock.withLock {
            if let engineFormat, let engine, engine.isRunning,
               engineFormat.sampleRate == format.sampleRate, engineFormat.channels == format.channels {
                return
            }
            stopEngine()
            try startEngine(format: format)
        }
    }

    /// Ends output and gives the audio hardware back.
    func stop() {
        streamFormat = nil
        engineLock.withLock {
            stopEngine()
        }
        state.withLock { $0.buffer = nil }
    }

    func clear() {
        state.withLock { $0.buffer?.clear() }
    }

    func enqueue(_ chunk: SendspinAudioChunk) {
        guard let format = streamFormat, format.codec == "pcm" else { return }
        do {
            let samples = try SendspinPCMDecoder.decode(
                chunk.payload,
                bitDepth: format.bitDepth,
                channels: format.channels
            )
            state.withLock { $0.buffer?.append(timestamp: chunk.timestamp, samples: samples) }
        } catch {
            Current.Log.error("Sendspin: dropping undecodable audio chunk: \(error)")
        }
    }

    // MARK: - Settings

    func update(mapping: SendspinClockMapping) {
        state.withLock { $0.mapping = mapping }
    }

    func setOutputDelay(milliseconds: Int) {
        state.withLock { $0.outputDelayMicroseconds = Int64(milliseconds) * 1000 }
    }

    /// Volume is perceived loudness, so it is converted with the curve the specification suggests.
    func setVolume(_ volume: Int, muted: Bool) {
        let gain = muted ? 0 : Float(pow(Double(min(max(volume, 0), 100)) / 100, 1.5))
        state.withLock { $0.targetGain = gain }
    }

    // MARK: - Engine

    private func startEngine(format: SendspinStreamFormat) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        guard let audioFormat = AVAudioFormat(
            standardFormatWithSampleRate: Double(format.sampleRate),
            channels: AVAudioChannelCount(format.channels)
        ) else {
            throw SendspinPCMDecoder.Failure.unsupportedBitDepth(format.bitDepth)
        }

        let engine = AVAudioEngine()
        let source = AVAudioSourceNode(format: audioFormat) { [weak self] _, timestamp, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            let pointers = buffers.compactMap { $0.mData?.assumingMemoryBound(to: Float.self) }
            let hostTime = timestamp.pointee.mFlags.contains(.hostTimeValid)
                ? timestamp.pointee.mHostTime
                : mach_absolute_time()
            self?.render(into: pointers, frameCount: Int(frameCount), hostTime: hostTime)
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: audioFormat)

        state.withLock {
            $0.buffer = SendspinPlaybackBuffer(sampleRate: Double(format.sampleRate), channels: format.channels)
        }
        refreshOutputLatency()
        engine.prepare()
        try engine.start()
        self.engine = engine
        engineFormat = format
    }

    private func stopEngine() {
        engine?.stop()
        engine = nil
        engineFormat = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func refreshOutputLatency() {
        let session = AVAudioSession.sharedInstance()
        let latency = Int64((session.outputLatency * 1_000_000).rounded())
        state.withLock { $0.outputLatencyMicroseconds = latency }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            onInterruption?(true)
        case .ended:
            if let format = engineLock.withLock({ engineFormat }) {
                try? start(format: format)
            }
            onInterruption?(false)
        @unknown default:
            break
        }
    }

    // MARK: - Render thread

    private func render(into output: [UnsafeMutablePointer<Float>], frameCount: Int, hostTime: UInt64) {
        // Unchecked because the closure touches the render buffers, which are only valid for this
        // call and never leave it.
        state.withLockUnchecked { state in
            guard state.buffer != nil else {
                for pointer in output {
                    pointer.update(repeating: 0, count: frameCount)
                }
                return
            }
            let heardAt = SendspinClock.microseconds(fromHostTime: hostTime) + state.outputLatencyMicroseconds
            let target = state.mapping.preciseServerTime(fromClient: Double(heardAt + state.outputDelayMicroseconds))
            state.lastOutcome = state.buffer?.render(into: output, frameCount: frameCount, targetServerTime: target)
                ?? .waiting

            // A short ramp across the cycle keeps volume changes from clicking.
            let start = state.currentGain
            let end = state.targetGain
            if start != 1 || end != 1 {
                let step = (end - start) / Float(max(frameCount, 1))
                for pointer in output {
                    for frame in 0 ..< frameCount {
                        pointer[frame] *= start + step * Float(frame)
                    }
                }
            }
            state.currentGain = end
        }
    }
}
