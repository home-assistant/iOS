import Foundation
@testable import HomeAssistant

final class MockAudioRecorderDelegate: AudioRecorderDelegate {
    var output = [Data]()
    var errors = [Error]()
    var stopped: (() -> Void)?

    func didOutputSample(data: Data) { output.append(data) }
    func didStartRecording(with sampleRate: Double) {}
    func didStopRecording() { stopped?() }
    func didFailToRecord(error: Error) { errors.append(error) }
}
