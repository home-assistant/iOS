import AVFoundation

protocol CameraCallAudio {
    func prepareForCall()
    func activate(_ audioSession: AVAudioSession)
    func deactivate(_ audioSession: AVAudioSession)
    func finishCall()
}
