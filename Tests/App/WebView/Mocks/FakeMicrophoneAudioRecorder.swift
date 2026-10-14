@testable import HomeAssistant
import Foundation

final class FakeMicrophoneAudioRecorder: MicrophoneAudioRecorderProtocol {
    var onFinish: ((_ successfully: Bool) -> Void)?
    var recordSucceeds = true
    private(set) var recordedDuration: TimeInterval?
    private(set) var stopCount = 0

    func record(forDuration duration: TimeInterval) -> Bool {
        recordedDuration = duration
        return recordSucceeds
    }

    func stop() {
        stopCount += 1
    }

    func finishOnItsOwn(successfully: Bool) {
        onFinish?(successfully)
    }
}
