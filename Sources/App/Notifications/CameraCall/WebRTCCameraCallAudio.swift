import AVFoundation
import Shared
import WebRTC

final class WebRTCCameraCallAudio: CameraCallAudio {
    func prepareForCall() {
        let session = RTCAudioSession.sharedInstance()
        session.useManualAudio = true
        session.isAudioEnabled = false
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetoothHFP]
            )
        } catch {
            Current.Log.error("Failed to configure the audio session for a camera call: \(error.localizedDescription)")
        }
    }

    func activate(_ audioSession: AVAudioSession) {
        let session = RTCAudioSession.sharedInstance()
        session.audioSessionDidActivate(audioSession)
        session.isAudioEnabled = true
    }

    func deactivate(_ audioSession: AVAudioSession) {
        let session = RTCAudioSession.sharedInstance()
        session.audioSessionDidDeactivate(audioSession)
        session.isAudioEnabled = false
    }

    func finishCall() {
        let session = RTCAudioSession.sharedInstance()
        session.isAudioEnabled = false
        session.useManualAudio = false
    }
}
