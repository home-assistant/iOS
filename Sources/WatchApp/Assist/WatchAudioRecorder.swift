import AVFoundation
import Combine
import Shared

protocol WatchAudioRecorderDelegate: AnyObject {
    func didStartRecording()
    func didStopRecording()
    /// Streaming recorders (`WatchStreamingAudioRecorder`): the 16-bit mono PCM captured since the
    /// previous call, delivered while the recording is still in progress. Arrives on the capture
    /// queue.
    func didOutputAudio(_ data: Data, sampleRate: Double)
    /// File recorders (`WatchAudioRecorder`): the whole recording, once it ended.
    func didFinishRecording(audioURL: URL, audioSampleRate: Double)
    func didFailRecording(error: Error)
    /// Normalized microphone input level (0...1) emitted while recording, for UI feedback.
    func didUpdateAudioLevel(_ level: Float)
}

extension WatchAudioRecorderDelegate {
    func didOutputAudio(_ data: Data, sampleRate: Double) {}
    func didFinishRecording(audioURL: URL, audioSampleRate: Double) {}
    func didUpdateAudioLevel(_ level: Float) {}
}

protocol WatchAudioRecorderProtocol: ObservableObject {
    var delegate: WatchAudioRecorderDelegate? { get set }
    func startRecording()
    func stopRecording()
}

/// Records Assist audio to a file and ends the recording itself after a stretch of silence.
///
/// - Note: Deprecated. `WatchStreamingAudioRecorder` streams the audio while it is captured so the
///   Assist pipeline's own voice-activity detection ends the recording; this recorder stays in use
///   outside TestFlight only until streaming graduates, and goes away with the ungating change.
final class WatchAudioRecorder: NSObject, WatchAudioRecorderProtocol {
    private enum Constants {
        /// Window of microphone average power (dBFS) mapped onto the 0...1 level, the same one the
        /// phone's orb uses: normal speech averages around -35...-18 dBFS, so a wider window leaves
        /// the orb barely moving.
        static let powerFloor: Float = -45
        static let powerCeiling: Float = -15
        /// The meter now drives the voice orb as well as the silence check, so it is read at about
        /// 20 Hz — often enough for the orb to follow speech, cheap enough for the watch.
        static let meteringInterval: TimeInterval = 1.0 / 20
    }

    private var audioRecorder: AVAudioRecorder?
    private var audioSampleRate: Double?
    weak var delegate: WatchAudioRecorderDelegate?

    private var meteringTimer: Timer?
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
        stopMonitoringAudioLevels()
        delegate?.didStopRecording()
    }

    private func getAudioFileURL() -> URL {
        let sharedGroupContainerDirectory = AppConstants.AppGroupContainer
        return sharedGroupContainerDirectory.appendingPathComponent("assist.wav")
    }

    private func startMonitoringAudioLevels() {
        meteringTimer?.invalidate()
        meteringTimer = Timer
            .scheduledTimer(withTimeInterval: Constants.meteringInterval, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                // A recording can end without going through `stopRecording()`: this monitoring starts a
                // second after the recorder does, so a stop in between lands first, and an interruption
                // ends the recording on its own. Returning would leave the timer firing 20 times a second
                // for as long as the app lives, so it is torn down here instead.
                guard let audioRecorder, audioRecorder.isRecording else {
                    stopMonitoringAudioLevels()
                    return
                }
                audioRecorder.updateMeters()

                let averagePower = audioRecorder.averagePower(forChannel: 0)
                let range = Constants.powerCeiling - Constants.powerFloor
                delegate?.didUpdateAudioLevel(max(0, min(1, (averagePower - Constants.powerFloor) / range)))

                // The first drop into silence starts the countdown that ends the recording. Metering
                // carries on through it — it is what the voice orb is drawn from — so the countdown is
                // tracked by its own timer rather than by replacing this one.
                guard averagePower < silenceLevel, silenceTimer == nil else { return }
                silenceTimer = Timer
                    .scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
                        self?.stopRecording()
                    }
            }
    }

    private func stopMonitoringAudioLevels() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
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
