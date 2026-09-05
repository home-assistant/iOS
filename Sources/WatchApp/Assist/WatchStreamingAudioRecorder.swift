import AVFoundation
import Combine
import Shared

/// Captures Assist audio and hands it to the delegate as it is recorded, instead of writing a file
/// and deciding on its own when the user stopped talking. Nothing here ends the recording apart
/// from `stopRecording()` and a duration cap: the Assist pipeline's voice-activity detection makes
/// that call, relayed back through the audio stream's acknowledgements.
///
/// Audio leaves the microphone in whatever format the watch captures and is converted to 16 kHz
/// 16-bit mono PCM, the format the pipeline is told to expect.
final class WatchStreamingAudioRecorder: WatchAudioRecorderProtocol {
    private enum StartError: Error {
        case noInputFormat
        case unsupportedFormat
    }

    private enum Constants {
        static let sampleRate: Double = 16000
        /// Frames per capture buffer at the input rate. Small enough to keep the first chunk's
        /// latency well under a quarter second, large enough not to wake the tap constantly.
        static let captureBufferSize: AVAudioFrameCount = 2048
        /// Window of microphone power (dBFS) mapped onto the 0...1 level, the same one the phone's
        /// orb uses: normal speech averages around -35...-18 dBFS.
        static let powerFloor: Float = -45
        static let powerCeiling: Float = -15
        /// The level drives the voice orb, so it is emitted at about 20 Hz — often enough for the
        /// orb to follow speech, cheap enough for the watch.
        static let levelInterval: TimeInterval = 1.0 / 20
        /// The only local end of a recording: a pipeline that never answers (no speech, a dropped
        /// link) must not keep the microphone open indefinitely. The server reports its own
        /// timeout well before this.
        static let maxDuration: TimeInterval = 30
    }

    weak var delegate: WatchAudioRecorderDelegate?

    private var engine: AVAudioEngine?
    private var durationCap: DispatchWorkItem?
    /// Only ever read and written on the tap's queue.
    private var lastLevelEmission: TimeInterval = .zero

    deinit {
        // The tap holds only a weak reference, so without this the microphone would stay open.
        teardown()
    }

    func startRecording() {
        guard engine == nil else {
            stopRecording()
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)

            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                throw StartError.noInputFormat
            }
            guard let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: Constants.sampleRate,
                channels: 1,
                interleaved: true
            ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                throw StartError.unsupportedFormat
            }
            Current.Log.verbose("Streaming Assist audio from \(inputFormat.sampleRate) Hz input")
            // The converter and format are captured rather than stored: the tap keeps running on
            // its own queue for a moment after `teardown()`, so it must not read state being torn
            // down.
            inputNode.installTap(
                onBus: 0,
                bufferSize: Constants.captureBufferSize,
                format: inputFormat
            ) { [weak self] buffer, _ in
                self?.process(buffer, converter: converter, outputFormat: outputFormat)
            }
            engine.prepare()
            // Announced before the engine runs so the first capture buffer can't beat it: the
            // delegate opens the audio stream on this call and drops audio that arrives earlier.
            delegate?.didStartRecording()
            try engine.start()
            self.engine = engine
            scheduleDurationCap()
        } catch {
            Current.Log.error("Failed to start streaming Assist audio: \(error.localizedDescription)")
            teardown()
            delegate?.didFailRecording(error: error)
        }
    }

    func stopRecording() {
        guard engine != nil else { return }
        teardown()
        delegate?.didStopRecording()
    }

    private func scheduleDurationCap() {
        let cap = DispatchWorkItem { [weak self] in
            Current.Log.info("Assist recording reached its duration cap")
            self?.stopRecording()
        }
        durationCap = cap
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.maxDuration, execute: cap)
    }

    private func teardown() {
        durationCap?.cancel()
        durationCap = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }

    /// Runs on the tap's queue: converts one capture buffer and hands the PCM to the delegate.
    private func process(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outputFormat: AVAudioFormat) {
        guard buffer.frameLength > 0 else { return }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        // The converter pulls input through this block; the one buffer is offered once and then
        // reported as exhausted, so each capture buffer converts on its own.
        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, conversionError == nil, let samples = converted.int16ChannelData else {
            Current.Log.error(
                "Assist audio conversion failed: \(conversionError?.localizedDescription ?? "unknown error")"
            )
            return
        }

        let frameCount = Int(converted.frameLength)
        guard frameCount > 0 else { return }
        emitLevelIfDue(samples: samples[0], frameCount: frameCount)
        let data = Data(bytes: samples[0], count: frameCount * MemoryLayout<Int16>.size)
        delegate?.didOutputAudio(data, sampleRate: outputFormat.sampleRate)
    }

    private func emitLevelIfDue(samples: UnsafePointer<Int16>, frameCount: Int) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastLevelEmission >= Constants.levelInterval else { return }
        lastLevelEmission = now

        var sumOfSquares: Float = 0
        for index in 0 ..< frameCount {
            let sample = Float(samples[index]) / Float(Int16.max)
            sumOfSquares += sample * sample
        }
        let rms = (sumOfSquares / Float(frameCount)).squareRoot()
        let power = 20 * log10(max(rms, .leastNonzeroMagnitude))
        let range = Constants.powerCeiling - Constants.powerFloor
        delegate?.didUpdateAudioLevel(max(0, min(1, (power - Constants.powerFloor) / range)))
    }
}
