import AVFoundation
import Foundation

/// Records the microphone into a 16 kHz, 16-bit mono WAV file.
final class MicrophoneAudioRecorder: NSObject, MicrophoneAudioRecorderProtocol {
    static let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    var onFinish: ((_ successfully: Bool) -> Void)?

    private let recorder: AVAudioRecorder

    /// The file type follows the extension of `fileURL`, so it should end in `.wav`.
    init(fileURL: URL) throws {
        self.recorder = try AVAudioRecorder(url: fileURL, settings: Self.settings)
        super.init()
        recorder.delegate = self
    }

    func record(forDuration duration: TimeInterval) -> Bool {
        recorder.prepareToRecord() && recorder.record(forDuration: duration)
    }

    func stop() {
        recorder.stop()
    }
}

extension MicrophoneAudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinish?(flag)
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinish?(false)
        }
    }
}
