import Accelerate
import AVFoundation
import Combine
import Shared

protocol WatchAudioRecorderDelegate: AnyObject {
    /// The recording started: the audio that follows is 16-bit mono PCM at `sampleRate`.
    func didStartRecording(sampleRate: Double)
    /// The audio captured since the last call, delivered while recording.
    func didRecordAudio(_ audio: Data)
    /// The recording ended after delivering all of its audio.
    func didStopRecording()
    /// The recording was discarded by `cancelRecording()`: nothing is sent.
    func didCancelRecording()
    func didFailRecording(error: Error)
    /// Normalized microphone input level (0...1) emitted while recording, for UI feedback.
    func didUpdateAudioLevel(_ level: Float)
}

extension WatchAudioRecorderDelegate {
    func didUpdateAudioLevel(_ level: Float) {}
}

protocol WatchAudioRecorderProtocol: ObservableObject {
    var delegate: WatchAudioRecorderDelegate? { get set }
    /// Starts recording, or stops the recording in progress.
    func startRecording()
    func stopRecording()
    /// Stop without delivering the audio.
    func cancelRecording()
}

/// Records the microphone for Assist and hands the audio over while it is captured, so it can be
/// streamed to the iPhone as the user speaks.
final class WatchAudioRecorder: NSObject, WatchAudioRecorderProtocol {
    private enum Constants {
        /// Window of microphone power (dBFS) mapped onto the 0...1 level, the same one the phone's
        /// orb uses: normal speech averages around -35...-18 dBFS, so a wider window leaves the orb
        /// barely moving.
        static let powerFloor: Float = -45
        static let powerCeiling: Float = -15
        /// The level drives the voice orb, so it is emitted at about 20 Hz — often enough for the orb
        /// to follow speech, cheap enough for the watch.
        static let levelInterval: TimeInterval = 1.0 / 20
        /// The orb stays still at first, so the sound played as the recording starts does not move it.
        static let levelDelay: TimeInterval = 1
        /// What Home Assistant's speech-to-text expects, and what recordings were always made in.
        static let sampleRate: Double = 16000
        /// Small, so the audio and the orb's level keep flowing between buffers.
        static let tapBufferSize: AVAudioFrameCount = 1024
        /// The tap only hands over whole buffers, so the microphone stays on this much longer once
        /// the recording is stopped: the buffer still filling holds the end of what was said.
        static let stopTail: TimeInterval = 0.3
    }

    /// The buffer one conversion feeds the converter, handed over once.
    private final class PendingInput {
        private var buffer: AVAudioPCMBuffer?

        init(_ buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }

        func take() -> AVAudioPCMBuffer? {
            defer { buffer = nil }
            return buffer
        }
    }

    weak var delegate: WatchAudioRecorderDelegate?

    private var engine: AVAudioEngine?
    /// Identifies the recording in progress, from the start until its stop is delivered. Audio the
    /// tap hands over for any other recording is dropped.
    private var recordingID: UUID?
    /// Whether the recording `recordingID` is still going: `false` from the moment it is stopped,
    /// while the microphone captures the tail.
    private var isCapturing = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionWasInterrupted),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
    }

    func startRecording() {
        if recordingID != nil {
            stopRecording()
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            try startCapture()
            delegate?.didStartRecording(sampleRate: Constants.sampleRate)
        } catch {
            finishCapture()
            recordingID = nil
            delegate?.didFailRecording(error: error)
        }
    }

    func stopRecording() {
        guard let recordingID, isCapturing else { return }
        isCapturing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.stopTail) { [weak self] in
            guard let self, self.recordingID == recordingID else { return }
            finishCapture()
            // The tap hands its audio to the main queue, so the stop goes through the main queue
            // too: the audio captured before it is delivered first.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.recordingID == recordingID else { return }
                self.recordingID = nil
                delegate?.didStopRecording()
            }
        }
    }

    /// Also drops a recording that is stopping but has not delivered its stop yet.
    func cancelRecording() {
        guard recordingID != nil else { return }
        finishCapture()
        recordingID = nil
        delegate?.didCancelRecording()
    }

    private func startCapture() throws {
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Constants.sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw WatchRecordingError.unsupportedFormat
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw WatchRecordingError.unsupportedFormat
        }

        let recordingID = UUID()
        let levelsStart = ProcessInfo.processInfo.systemUptime + Constants.levelDelay
        // Only touched by the tap, which calls back serially.
        var lastLevelEmission: TimeInterval = .zero
        inputNode.installTap(
            onBus: 0,
            bufferSize: Constants.tapBufferSize,
            format: inputFormat
        ) { [weak self] buffer, _ in
            let audio = Self.convert(buffer, with: converter, to: outputFormat)

            let now = ProcessInfo.processInfo.systemUptime
            let emitsLevel = now >= levelsStart && now - lastLevelEmission >= Constants.levelInterval
            if emitsLevel {
                lastLevelEmission = now
            }
            let level = emitsLevel ? Self.level(of: buffer) : nil

            DispatchQueue.main.async {
                guard let self, self.recordingID == recordingID else { return }
                if let audio {
                    self.delegate?.didRecordAudio(audio)
                }
                if let level {
                    self.delegate?.didUpdateAudioLevel(level)
                }
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw error
        }
        self.engine = engine
        self.recordingID = recordingID
        isCapturing = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(engineConfigurationChanged),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }

    private func finishCapture() {
        isCapturing = false
        guard let engine else { return }
        NotificationCenter.default.removeObserver(self, name: .AVAudioEngineConfigurationChange, object: engine)
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }

    /// The microphone's audio as 16-bit mono PCM at `Constants.sampleRate`, or `nil` when it yields
    /// nothing yet: the converter can hold a few frames back between calls while resampling.
    private static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> Data? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        let input = PendingInput(buffer)
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            // `.noDataNow` rather than `.endOfStream`: the recording goes on, and the converter keeps
            // its resampling state for the next buffer.
            guard let buffer = input.take() else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, output.frameLength > 0, let samples = output.int16ChannelData else {
            if let error {
                Current.Log.error("Failed to convert Assist audio: \(error.localizedDescription)")
            }
            return nil
        }
        return Data(bytes: samples[0], count: Int(output.frameLength) * MemoryLayout<Int16>.size)
    }

    private static func level(of buffer: AVAudioPCMBuffer) -> Float? {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return nil }
        var meanSquare: Float = 0
        vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(buffer.frameLength))
        let decibels = 20 * log10(max(sqrt(meanSquare), .leastNormalMagnitude))
        let range = Constants.powerCeiling - Constants.powerFloor
        return max(0, min(1, (decibels - Constants.powerFloor) / range))
    }

    /// The audio route changed — headphones connected, say — and the engine stopped with it: what was
    /// said so far is sent rather than waiting on a microphone that is no longer captured.
    @objc private func engineConfigurationChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.stopRecording()
        }
    }

    /// An interruption — a call, an alarm — takes the microphone away: what was said so far is sent.
    @objc private func audioSessionWasInterrupted(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: rawType) == .began else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.stopRecording()
        }
    }
}

enum WatchRecordingError: Error {
    case unsupportedFormat
}
