import AVFoundation
import Foundation
import Shared

protocol AudioRecorderProtocol {
    var delegate: AudioRecorderDelegate? { get set }
    var audioSampleRate: Double? { get }
    var managesAudioSession: Bool { get set }
    func startRecording()
    func stopRecording()
}

protocol AudioRecorderDelegate: AnyObject {
    func didOutputSample(data: Data)
    func didStartRecording(with sampleRate: Double)
    func didStopRecording()
    func didFailToRecord(error: Error)
    /// Normalized microphone input level (0...1) emitted while recording, for UI feedback.
    func didUpdateAudioLevel(_ level: Float)
}

extension AudioRecorderDelegate {
    func didUpdateAudioLevel(_ level: Float) {}
}

enum AudioRecorderError: Error {
    case invalidSampleRate
    case captureDeviceUnavailable
}

final class AudioRecorder: NSObject, AudioRecorderProtocol {
    private enum Constants {
        /// Window of microphone average power (dBFS) mapped onto the 0...1 level. Kept narrow on purpose:
        /// normal speech averages around -35...-18 dBFS, so a wider window leaves the orb barely moving.
        static let powerFloor: Float = -45
        static let powerCeiling: Float = -15
        /// Buffers arrive far faster than a screen refresh, and every level costs the main thread a
        /// published change, so they are emitted at about 30 Hz instead of once per buffer.
        static let levelInterval: TimeInterval = 1.0 / 30
    }

    weak var delegate: AudioRecorderDelegate?
    var managesAudioSession = true

    private(set) var audioSampleRate: Double?
    private var captureSession: AVCaptureSession?
    /// Only ever read and written on the sample buffer delegate's own queue.
    private var lastLevelEmission: TimeInterval = .zero

    /// Everything that touches the capture session runs here. Configuring one blocks: `init` alone
    /// makes a synchronous XPC call to LaunchServices, and `startRunning`/`stopRunning` wait on the
    /// media server, which is enough to hang the main thread for hundreds of milliseconds. A serial
    /// queue also keeps a stop from overtaking the start it belongs to.
    private let sessionQueue = DispatchQueue(label: "assist-audio-recorder-session", qos: .userInitiated)

    override init() {
        super.init()
        registerForRecordingNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            setupAudioRecorder()
            // A failed setup has already told the delegate why.
            guard let captureSession else { return }
            guard let audioSampleRate else {
                Current.Log.error("No sample rate available to start recording")
                return
            }
            captureSession.startRunning()
            delegate?.didStartRecording(with: audioSampleRate)
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.delegate?.didStopRecording()
        }
    }

    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        guard let captureDevice = AVCaptureDevice.default(for: .audio) else {
            Current.Log.error("Failed to get capture device to record audio for Assist")
            delegate?.didFailToRecord(error: AudioRecorderError.captureDeviceUnavailable)
            return
        }

        do {
            if managesAudioSession {
                try audioSession.setActive(false)
                try audioSession.setCategory(.record, mode: .default)
                try audioSession.setPreferredOutputNumberOfChannels(1)
                try audioSession.setPreferredSampleRate(16000.0)
                try audioSession.setActive(true)
            }
            let audioInput = try AVCaptureDeviceInput(device: captureDevice)

            captureSession = AVCaptureSession()
            captureSession?.automaticallyConfiguresApplicationAudioSession = false
            captureSession?.addInput(audioInput)

            Current.Log.info("Audio sample rate: \(audioSession.sampleRate)")
            if audioSession.sampleRate == 0 {
                throw AudioRecorderError.invalidSampleRate
            } else {
                audioSampleRate = audioSession.sampleRate
            }

            let audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))
            captureSession?.addOutput(audioOutput)
        } catch {
            Current.Log.error("Error starting audio streaming: \(error.localizedDescription)")
            delegate?.didFailToRecord(error: error)
        }
    }

    private func registerForRecordingNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidStopRunning),
            name: .AVCaptureSessionDidStopRunning,
            object: captureSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: .AVCaptureSessionRuntimeError,
            object: captureSession
        )
    }

    @objc private func sessionDidStopRunning(notification: Notification) {
        delegate?.didStopRecording()
    }

    @objc private func sessionRuntimeError(notification: Notification) {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            let message = "AVCaptureSession runtime error: \(error)"
            Current.Log.error(message)
            delegate?.didFailToRecord(error: error)
        }
        delegate?.didStopRecording()
    }
}

extension AudioRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let data = sampleBuffer.audioSamples() else {
            Current.Log.error("Failed to extract audio samples from CMSampleBuffer")
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        if now - lastLevelEmission >= Constants.levelInterval,
           let averagePower = connection.audioChannels.first?.averagePowerLevel {
            lastLevelEmission = now
            let range = Constants.powerCeiling - Constants.powerFloor
            let level = max(0, min(1, (averagePower - Constants.powerFloor) / range))
            delegate?.didUpdateAudioLevel(level)
        }

        delegate?.didOutputSample(data: data)
    }
}
