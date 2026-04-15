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

    private var assistService: AssistServiceProtocol
    private var audioRecorder: AudioRecorderProtocol
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

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Current.Log.error("CarPlay Assist failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - TTS Playback

    /// Plays TTS audio directly via AVPlayer, bypassing the phone volume check
    /// that would incorrectly skip playback in the CarPlay context.
    private func playTTS(url: URL) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            Current.Log.error("CarPlay Assist failed to setup audio session for TTS: \(error.localizedDescription)")
        }

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

// MARK: - AssistServiceDelegate

@available(iOS 16.0, *)
extension CarPlayAssistSession: AssistServiceDelegate {
    func didReceiveGreenLightForAudioInput() {
        stateQueue.sync { canSendAudioData = true }
    }

    func didReceiveEvent(_ event: AssistEvent) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        if event == .sttEnd {
            audioRecorder.stopRecording()
            assistService.finishSendingAudio()
            stateQueue.sync {
                canSendAudioData = false
                state = .processing
            }
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
