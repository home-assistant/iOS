import AVFoundation
import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayAssistSession: NSObject {
    enum State {
        case recording
        case processing
        case responding
        case error(String)
        case done

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    weak var interfaceController: CPInterfaceController?

    private var assistService: AssistServiceProtocol
    private var audioRecorder: AudioRecorderProtocol
    private let ttsPlayer = AVPlayer()
    private var canSendAudioData = false
    private var state: State = .recording
    private var isStopped = false

    private let server: Server
    private let pipelineId: String
    private let pipelineName: String

    private lazy var template: CPListTemplate = {
        let template = CPListTemplate(title: pipelineName, sections: [])
        template.backButton = CPBarButton(title: L10n.Alerts.Confirm.cancel) { [weak self] _ in
            self?.stop()
        }
        return template
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
        state = .recording
        updateTemplateForCurrentState()
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
        audioRecorder.startRecording()
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        audioRecorder.stopRecording()
        assistService.finishSendingAudio()
        ttsPlayer.pause()
        canSendAudioData = false
        NotificationCenter.default.removeObserver(self)
        interfaceController?.popTemplate(animated: true, completion: nil)
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
        guard !isStopped else { return }
        if assistService.shouldStartListeningAgainAfterPlaybackEnd {
            assistService.resetShouldStartListeningAgainAfterPlaybackEnd()
            restartRecording()
        } else {
            state = .done
            updateTemplateForCurrentState()
        }
    }

    // MARK: - Template Updates

    private func updateTemplateForCurrentState() {
        let item = listItemForState()
        if Thread.isMainThread {
            template.updateSections([CPListSection(items: [item])])
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.template.updateSections([CPListSection(items: [item])])
            }
        }
    }

    private func listItemForState() -> CPListItem {
        let item: CPListItem
        switch state {
        case .recording:
            item = CPListItem(
                text: L10n.Assist.Button.Listening.title,
                detailText: nil,
                image: MaterialDesignIcons.microphoneIcon.carPlayIcon(color: .haPrimary)
            )
            item.handler = { [weak self] _, completion in
                self?.stopRecordingAndSend()
                completion()
            }
        case .processing:
            item = CPListItem(
                text: L10n.Assist.Carplay.Processing.title,
                detailText: nil,
                image: MaterialDesignIcons.dotsHorizontalIcon.carPlayIcon(color: .haPrimary)
            )
        case .responding:
            item = CPListItem(
                text: L10n.Assist.Carplay.Responding.title,
                detailText: nil,
                image: MaterialDesignIcons.volumeHighIcon.carPlayIcon(color: .haPrimary)
            )
        case let .error(message):
            item = CPListItem(
                text: message,
                detailText: nil,
                image: MaterialDesignIcons.alertCircleIcon.carPlayIcon(color: .red)
            )
            item.handler = { [weak self] _, completion in
                self?.restartRecording()
                completion()
            }
        case .done:
            item = CPListItem(
                text: L10n.Assist.Carplay.TapToRecord.title,
                detailText: nil,
                image: MaterialDesignIcons.microphoneIcon.carPlayIcon(color: .haPrimary)
            )
            item.handler = { [weak self] _, completion in
                self?.restartRecording()
                completion()
            }
        }
        return item
    }

    private func stopRecordingAndSend() {
        audioRecorder.stopRecording()
        assistService.finishSendingAudio()
        canSendAudioData = false
        state = .processing
        updateTemplateForCurrentState()
    }

    private func restartRecording() {
        canSendAudioData = false
        state = .recording
        updateTemplateForCurrentState()
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
        guard canSendAudioData else { return }
        assistService.sendAudioData(data)
    }

    func didStopRecording() {
        // Recording stopped, waiting for server processing
    }

    func didFailToRecord(error: any Error) {
        guard !isStopped, !state.isError else { return }
        Current.Log.error("CarPlay Assist recording failed: \(error.localizedDescription)")
        state = .error(error.localizedDescription)
        updateTemplateForCurrentState()
    }
}

// MARK: - AssistServiceDelegate

@available(iOS 16.0, *)
extension CarPlayAssistSession: AssistServiceDelegate {
    func didReceiveGreenLightForAudioInput() {
        canSendAudioData = true
    }

    func didReceiveEvent(_ event: AssistEvent) {
        guard !isStopped else { return }
        if event == .sttEnd {
            audioRecorder.stopRecording()
            assistService.finishSendingAudio()
            canSendAudioData = false
            state = .processing
            updateTemplateForCurrentState()
        }
    }

    func didReceiveSttContent(_ content: String) {
        // No text display in CarPlay per Apple requirements
    }

    func didReceiveStreamResponseChunk(_ content: String) {
        // No text display in CarPlay per Apple requirements
    }

    func didReceiveIntentEndContent(_ content: String) {
        guard !isStopped else { return }
        state = .responding
        updateTemplateForCurrentState()
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        guard !isStopped else { return }
        playTTS(url: mediaUrl)
    }

    func didReceiveError(code: String, message: String) {
        guard !isStopped else { return }
        Current.Log.error("CarPlay Assist error [\(code)]: \(message)")
        state = .error(message)
        updateTemplateForCurrentState()
    }
}
