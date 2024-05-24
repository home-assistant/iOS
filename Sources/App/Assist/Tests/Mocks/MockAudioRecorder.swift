@testable import HomeAssistant

final class MockAudioRecorder: AudioRecorderProtocol {
    weak var delegate: AudioRecorderDelegate?
    var audioSampleRate: Double?

    var startRecordingCalled = false
    var stopRecordingCalled = false

    func startRecording() {
        startRecordingCalled = true
    }

    func stopRecording() {
        stopRecordingCalled = true
    }
}
