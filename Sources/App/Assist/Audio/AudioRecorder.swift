import AVFoundation
import Foundation
import Shared

protocol AudioRecorderProtocol {
    var delegate: AudioRecorderDelegate? { get set }
    var audioSampleRate: Double? { get }
    func startRecording()
    func stopRecording()
}

protocol AudioRecorderDelegate: AnyObject {
    func didOutputSample(data: Data)
    func didStartRecording(with sampleRate: Double)
    func didStopRecording()
    func didFailToRecord(error: Error)
}

enum AudioRecorderError: Error {
    case invalidSampleRate
}

final class AudioRecorder: NSObject, AudioRecorderProtocol {
    weak var delegate: AudioRecorderDelegate?

    private(set) var audioSampleRate: Double?
    private var captureSession: AVCaptureSession?

    override init() {
        super.init()
        registerForRecordingNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func startRecording() {
        setupAudioRecorder()
        guard let captureSession else { return }
        DispatchQueue.global().async { [weak self] in
            if let audioSampleRate = self?.audioSampleRate {
                captureSession.startRunning()
                self?.delegate?.didStartRecording(with: audioSampleRate)
            } else {
                Current.Log.error("No sample rate available to start recording")
            }
        }
    }

    func stopRecording() {
        captureSession?.stopRunning()
        delegate?.didStopRecording()
    }

    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        guard let captureDevice = AVCaptureDevice.default(for: .audio) else {
            Current.Log.error("Failed to get capture device to record audio for Assist")
            return
        }

        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setPreferredSampleRate(16000)
            try audioSession.setPreferredOutputNumberOfChannels(1)

            try audioSession.setActive(true)
            let audioInput = try AVCaptureDeviceInput(device: captureDevice)

            captureSession = AVCaptureSession()
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
            selector: #selector(sessionDidStartRunning),
            name: .AVCaptureSessionDidStartRunning,
            object: captureSession
        )

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

    @objc private func sessionDidStartRunning(notification: Notification) {
        if let audioSampleRate {
            delegate?.didStartRecording(with: audioSampleRate)
        } else {
            Current.Log.error("Audio recorded sessionDidStartRunning triggered without audioSampleRate")
        }
    }

    @objc private func sessionDidStopRunning(notification: Notification) {
        delegate?.didStopRecording()
    }

    @objc private func sessionRuntimeError(notification: Notification) {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            let message = "AVCaptureSession runtime error: \(error)"
            Current.Log.error(message)
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

        delegate?.didOutputSample(data: data)
    }
}
