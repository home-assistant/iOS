import Foundation
@testable import HomeAssistant

final class MockAudioRecorderDelegate: AudioRecorderDelegate {
    var output = [Data]()
    var errors = [Error]()
    var startedSampleRates = [Double]()
    var stopped: (() -> Void)?
    var failed: ((Error) -> Void)?

    func didOutputSample(data: Data) { output.append(data) }
    func didStartRecording(with sampleRate: Double) { startedSampleRates.append(sampleRate) }
    func didStopRecording() { stopped?() }
    func didFailToRecord(error: Error) {
        errors.append(error)
        failed?(error)
    }
}
