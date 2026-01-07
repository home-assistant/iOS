@testable import HomeAssistant
import AVFoundation

final class MockAudioRecorder: AudioRecorderProtocol {
    weak var delegate: AudioRecorderDelegate?
    var audioSampleRate: Double?
    var selectedAudioDevice: AVCaptureDevice?

    var startRecordingCalled = false
    var stopRecordingCalled = false

    func startRecording() {
        startRecordingCalled = true
    }

    func stopRecording() {
        stopRecordingCalled = true
    }

    func availableAudioDevices() -> [AVCaptureDevice] {
        []
    }
}
