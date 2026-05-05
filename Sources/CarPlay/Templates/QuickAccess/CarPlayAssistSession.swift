import AudioToolbox
import AVFoundation
import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayAssistSession: NSObject {
    typealias OnStop = () -> Void

    enum State {
        case recording
        case processing
        case responding
        case error(String)

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    private enum VoiceControlStateID: String {
        case recording
        case processing
        case responding
    }

    weak var interfaceController: CPInterfaceController?
    var onStop: OnStop?

    private let audioSession = AVAudioSession.sharedInstance()
    private var assistService: AssistServiceProtocol
    private var audioRecorder: AudioRecorderProtocol
    private var recordingIndicatorPlayer: AVAudioPlayer?
    private let ttsPlayer = AVPlayer()

    /// Serial queue protecting all mutable session state (`canSendAudioData`, `state`, `isStopped`).
    /// Callbacks from AVCaptureSession, HAKit, and NotificationCenter may arrive on arbitrary threads.
    private let stateQueue = DispatchQueue(label: "io.home-assistant.carplay-assist-session", qos: .userInteractive)
    private var canSendAudioData = false
    private var state: State = .recording
    private var isStopped = false

    private let server: Server
    private let pipelineId: String
    private let pipelineName: String

    private lazy var template: CPVoiceControlTemplate = {
        let recordingState = CPVoiceControlState(
            identifier: VoiceControlStateID.recording.rawValue,
            titleVariants: [L10n.Assist.Button.Listening.title],
            image: MaterialDesignIcons.microphoneIcon.carPlayIcon(color: .haPrimary),
            repeats: true
        )
        let processingState = CPVoiceControlState(
            identifier: VoiceControlStateID.processing.rawValue,
            titleVariants: [L10n.Assist.Carplay.Processing.title],
            image: MaterialDesignIcons.dotsHorizontalIcon.carPlayIcon(color: .haPrimary),
            repeats: true
        )
        let respondingState = CPVoiceControlState(
            identifier: VoiceControlStateID.responding.rawValue,
            titleVariants: [L10n.Assist.Carplay.Responding.title],
            image: MaterialDesignIcons.volumeHighIcon.carPlayIcon(color: .haPrimary),
            repeats: true
        )
        return CPVoiceControlTemplate(voiceControlStates: [recordingState, processingState, respondingState])
    }()

    init(
        interfaceController: CPInterfaceController?,
        server: Server,
        pipelineId: String,
        pipelineName: String,
        audioRecorder: AudioRecorderProtocol = AudioRecorder(),
        assistService: AssistServiceProtocol? = nil
    ) {
        self.interfaceController = interfaceController
        self.server = server
        self.pipelineId = pipelineId
        self.pipelineName = pipelineName
        self.audioRecorder = audioRecorder
        self.assistService = assistService ?? AssistService(server: server)
        super.init()
        self.audioRecorder.managesAudioSession = Current.settingsStore.carPlayAssistRecorderManagesAudioSession
        registerForAudioSessionNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        audioRecorder.delegate = self
        assistService.delegate = self
        stateQueue.sync {
            state = .recording
            isStopped = false
            canSendAudioData = false
        }
        configureAudioSessionForAssist()
        activateVoiceControlState(for: .recording)
        interfaceController?.presentTemplate(template, animated: true, completion: nil)
        audioRecorder.startRecording()
    }

    func stop() {
        stop(dismissTemplate: true)
    }

    func templateWillDisappear(template disappearingTemplate: CPTemplate) {
        guard disappearingTemplate === template else { return }
        stop(dismissTemplate: false)
    }

    private func stop(dismissTemplate: Bool) {
        let alreadyStopped: Bool = stateQueue.sync {
            if isStopped { return true }
            isStopped = true
            canSendAudioData = false
            return false
        }
        guard !alreadyStopped else { return }
        audioRecorder.stopRecording()
        assistService.finishSendingAudio()
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        deactivateAudioSession()
        NotificationCenter.default.removeObserver(self)
        if dismissTemplate {
            interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
        onStop?()
    }

    // MARK: - Audio Session

    private func configureAudioSessionForAssist() {
        do {
            var options: AVAudioSession.CategoryOptions = []
            if Current.settingsStore.carPlayAssistAllowBluetoothHFP {
                options.insert(.allowBluetoothHFP)
            }
            if Current.settingsStore.carPlayAssistAllowBluetoothA2DP {
                options.insert(.allowBluetoothA2DP)
            }

            try audioSession.setCategory(
                Current.settingsStore.carPlayAssistAudioCategory.avCategory,
                mode: Current.settingsStore.carPlayAssistAudioMode.avMode,
                options: options
            )
            try audioSession.setPreferredSampleRate(16000.0)
            try audioSession.setActive(true)
            logCurrentAudioRoute(context: "activated")
        } catch {
            Current.Log.error("CarPlay Assist failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Current.Log.error("CarPlay Assist failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    private func registerForAudioSessionNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesWereReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession
        )
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            Current.Log.error("CarPlay Assist received audio interruption without a valid type")
            return
        }

        switch type {
        case .began:
            Current.Log.info("CarPlay Assist audio session interruption began")
            let stopped = stateQueue.sync { isStopped }
            guard !stopped else { return }
            stop()
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            Current.Log
                .info(
                    "CarPlay Assist audio session interruption ended, shouldResume: \(options.contains(.shouldResume))"
                )
        @unknown default:
            Current.Log.info("CarPlay Assist audio session interruption ended with unknown type")
        }
    }

    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        let reasonDescription: String
        if let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
           let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) {
            reasonDescription = String(describing: reason)
        } else {
            reasonDescription = "unknown"
        }

        Current.Log.info("CarPlay Assist audio route changed: \(reasonDescription)")
        logCurrentAudioRoute(context: "route change")
    }

    @objc private func handleMediaServicesWereReset() {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }

        Current.Log.error("CarPlay Assist audio media services were reset")
        configureAudioSessionForAssist()
    }

    private func logCurrentAudioRoute(context: String) {
        let inputs = audioSession.currentRoute.inputs.map(\.portType.rawValue).joined(separator: ",")
        let outputs = audioSession.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ",")
        Current.Log.info("CarPlay Assist audio route \(context). inputs: [\(inputs)] outputs: [\(outputs)]")
    }

    private func playRecordingIndicatorToneIfNeeded() {
        guard Current.settingsStore.carPlayAssistPlayRecordingIndicatorTone else { return }

        do {
            recordingIndicatorPlayer = try AVAudioPlayer(data: Self.recordingIndicatorToneData)
            recordingIndicatorPlayer?.volume = 0.7
            recordingIndicatorPlayer?.prepareToPlay()
            recordingIndicatorPlayer?.play()
        } catch {
            Current.Log.error("CarPlay Assist failed to play recording indicator tone: \(error.localizedDescription)")
            AudioServicesPlaySystemSound(1113)
        }
    }

    // MARK: - TTS Playback

    /// Plays TTS audio using the already active conversational audio session to preserve the car route.
    private func playTTS(url: URL) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        let playerItem = AVPlayerItem(url: url)
        ttsPlayer.replaceCurrentItem(with: playerItem)
        ttsPlayer.play()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ttsDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    @objc private func ttsDidFinishPlaying(_ notification: Notification) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        if assistService.shouldStartListeningAgainAfterPlaybackEnd {
            assistService.resetShouldStartListeningAgainAfterPlaybackEnd()
            restartRecording()
        } else {
            stop()
        }
    }

    // MARK: - Voice Control State Updates

    private func activateVoiceControlState(for state: State) {
        let identifier: String
        switch state {
        case .recording:
            identifier = VoiceControlStateID.recording.rawValue
        case .processing:
            identifier = VoiceControlStateID.processing.rawValue
        case .responding:
            identifier = VoiceControlStateID.responding.rawValue
        case .error:
            return
        }
        if Thread.isMainThread {
            template.activateVoiceControlState(withIdentifier: identifier)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.template.activateVoiceControlState(withIdentifier: identifier)
            }
        }
    }

    private func restartRecording() {
        stateQueue.sync {
            canSendAudioData = false
            state = .recording
        }
        activateVoiceControlState(for: .recording)
        audioRecorder.startRecording()
    }
}

// MARK: - AudioRecorderDelegate

@available(iOS 16.0, *)
extension CarPlayAssistSession: AudioRecorderDelegate {
    func didStartRecording(with sampleRate: Double) {
        playRecordingIndicatorToneIfNeeded()
        assistService.assist(source: .audio(
            pipelineId: pipelineId,
            audioSampleRate: sampleRate,
            tts: true
        ))
    }

    func didOutputSample(data: Data) {
        let canSend = stateQueue.sync { canSendAudioData && !isStopped }
        guard canSend else { return }
        assistService.sendAudioData(data)
    }

    func didStopRecording() {
        // Recording stopped, waiting for server processing
    }

    func didFailToRecord(error: any Error) {
        let shouldHandle: Bool = stateQueue.sync {
            guard !isStopped, !state.isError else { return false }
            state = .error(error.localizedDescription)
            return true
        }
        guard shouldHandle else { return }
        Current.Log.error("CarPlay Assist recording failed: \(error.localizedDescription)")
        stop()
    }
}

@available(iOS 16.0, *)
private extension CarPlayAssistSession {
    static let recordingIndicatorToneData: Data = {
        let sampleRate = 24000
        let duration = 0.12
        let frequency = 880.0
        let frameCount = Int(Double(sampleRate) * duration)
        let amplitude = 0.25

        var pcmData = Data(capacity: frameCount * MemoryLayout<Int16>.size)

        for frame in 0 ..< frameCount {
            let progress = Double(frame) / Double(frameCount)
            let envelope = min(progress / 0.1, (1.0 - progress) / 0.15, 1.0)
            let sample = sin(2.0 * .pi * frequency * progress * duration) * amplitude * envelope
            let intSample = Int16(max(-1.0, min(1.0, sample)) * Double(Int16.max))
            var littleEndianSample = intSample.littleEndian
            pcmData.append(Data(bytes: &littleEndianSample, count: MemoryLayout<Int16>.size))
        }

        let bytesPerSample = MemoryLayout<Int16>.size
        let subchunk2Size = frameCount * bytesPerSample
        let chunkSize = 36 + subchunk2Size
        let byteRate = sampleRate * bytesPerSample
        let blockAlign = UInt16(bytesPerSample)
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let audioFormat: UInt16 = 1

        func littleEndianData<T: FixedWidthInteger>(_ value: T) -> Data {
            var littleEndian = value.littleEndian
            return Data(bytes: &littleEndian, count: MemoryLayout<T>.size)
        }

        var wavData = Data()
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(littleEndianData(UInt32(chunkSize)))
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(littleEndianData(UInt32(16)))
        wavData.append(littleEndianData(audioFormat))
        wavData.append(littleEndianData(channels))
        wavData.append(littleEndianData(UInt32(sampleRate)))
        wavData.append(littleEndianData(UInt32(byteRate)))
        wavData.append(littleEndianData(blockAlign))
        wavData.append(littleEndianData(bitsPerSample))
        wavData.append("data".data(using: .ascii)!)
        wavData.append(littleEndianData(UInt32(subchunk2Size)))
        wavData.append(pcmData)
        return wavData
    }()
}

// MARK: - AssistServiceDelegate

@available(iOS 16.0, *)
extension CarPlayAssistSession: AssistServiceDelegate {
    func didReceiveGreenLightForAudioInput() {
        stateQueue.sync { canSendAudioData = true }
    }

    func didReceiveEvent(_ event: AssistEvent) {
        if event == .sttEnd {
            let shouldHandleSttEnd = stateQueue.sync { () -> Bool in
                guard !isStopped else { return false }
                canSendAudioData = false
                state = .processing
                return true
            }
            guard shouldHandleSttEnd else { return }
            audioRecorder.stopRecording()
            assistService.finishSendingAudio()
            activateVoiceControlState(for: .processing)
        }
    }

    func didReceiveSttContent(_ content: String) {
        // No text display in CarPlay
    }

    func didReceiveStreamResponseChunk(_ content: String) {
        // No text display in CarPlay
    }

    func didReceiveIntentEndContent(_ content: String) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        stateQueue.sync { state = .responding }
        activateVoiceControlState(for: .responding)
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        playTTS(url: mediaUrl)
    }

    func didReceiveError(code: String, message: String) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        Current.Log.error("CarPlay Assist error [\(code)]: \(message)")
        stateQueue.sync { state = .error(message) }
        stop()
    }
}
