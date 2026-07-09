import AVFoundation
import Combine
import Shared

protocol WatchAudioRecorderDelegate: AnyObject {
    func didStartRecording()
    func didStopRecording()
    func didFinishRecording(audioURL: URL, audioSampleRate: Double)
    func didFailRecording(error: Error)
}

protocol WatchAudioRecorderProtocol: ObservableObject {
    var delegate: WatchAudioRecorderDelegate? { get set }
    func startRecording()
    func stopRecording()
}

final class WatchAudioRecorder: NSObject, WatchAudioRecorderProtocol {
    private var audioRecorder: AVAudioRecorder?
    private var audioSampleRate: Double?
    weak var delegate: WatchAudioRecorderDelegate?

    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 3.0
    private let silenceLevel: Float = -50.0

    private var firstLaunch = true

    func startRecording() {
        if audioRecorder?.isRecording ?? false {
            stopRecording()
            return
        }
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setActive(false)
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue,
            ]

            let url = getAudioFileURL()
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            audioSampleRate = audioRecorder?.format.sampleRate
            Current.Log.verbose("Using audio sample rate \(String(describing: audioSampleRate))")
            audioRecorder?.record()

            delegate?.didStartRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startMonitoringAudioLevels()
            }
        } catch {
            delegate?.didFailRecording(error: error)
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        delegate?.didStopRecording()
    }

    private func getAudioFileURL() -> URL {
        let sharedGroupContainerDirectory = AppConstants.AppGroupContainer
        return sharedGroupContainerDirectory.appendingPathComponent("assist.wav")
    }

    private func startMonitoringAudioLevels() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let audioRecorder, audioRecorder.isRecording else { return }
            audioRecorder.updateMeters()

            let averagePower = audioRecorder.averagePower(forChannel: 0)
            #if DEBUG
            print("Average power channel 0: \(audioRecorder.averagePower(forChannel: 0))")
            #endif
            if averagePower < silenceLevel {
                silenceTimer?.invalidate()
                silenceTimer = Timer
                    .scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
                        self?.stopRecording()
                    }
            }
        }
    }
}

extension WatchAudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if let audioSampleRate {
            delegate?.didFinishRecording(audioURL: getAudioFileURL(), audioSampleRate: audioSampleRate)
        } else {
            Current.Log.error("Finished recording without audio sample rate available")
            delegate?.didFailRecording(error: WatchRecordingError.noAudioSampleRate)
        }

        #if DEBUG
        print(getAudioFileURL())
        #endif
    }
}

enum WatchRecordingError: Error {
    case noAudioSampleRate
}
