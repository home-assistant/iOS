import AVFoundation
@testable import HomeAssistant

final class FakeCameraCallAudio: CameraCallAudio {
    enum Event: Equatable {
        case prepared
        case activated
        case deactivated
        case finished
    }

    private(set) var events: [Event] = []

    func prepareForCall() {
        events.append(.prepared)
    }

    func activate(_ audioSession: AVAudioSession) {
        events.append(.activated)
    }

    func deactivate(_ audioSession: AVAudioSession) {
        events.append(.deactivated)
    }

    func finishCall() {
        events.append(.finished)
    }
}
