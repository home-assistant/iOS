import AVFoundation
import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayAssistSession {
    enum State {
        case recording
        case processing
        case responding
        case error(String)
        case done
    }

    weak var interfaceController: CPInterfaceController?

    private var assistService: AssistServiceProtocol
    private var audioRecorder: AudioRecorderProtocol
    private var audioPlayer: AudioPlayerProtocol
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
        audioPlayer: AudioPlayerProtocol = AudioPlayer(),
        assistService: AssistServiceProtocol? = nil
    ) {
        self.interfaceController = interfaceController
        self.server = server
        self.pipelineId = pipelineId
        self.pipelineName = pipelineName
        self.audioRecorder = audioRecorder
        self.audioPlayer = audioPlayer
        self.assistService = assistService ?? AssistService(server: server)
    }

    func start() {
        audioRecorder.delegate = self
        assistService.delegate = self
        audioPlayer.delegate = self
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
        audioPlayer.pause()
        canSendAudioData = false
        interfaceController?.popTemplate(animated: true, completion: nil)
    }

    // MARK: - Template Updates

    private func updateTemplateForCurrentState() {
        let item = listItemForState()
        template.updateSections([CPListSection(items: [item])])
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
                self?.toggleRecording()
                completion()
            }
        case .processing:
            item = CPListItem(
                text: L10n.Assist.Button.FinishRecording.title,
                detailText: nil,
                image: MaterialDesignIcons.dotsHorizontalIcon.carPlayIcon(color: .haPrimary)
            )
        case .responding:
            item = CPListItem(
                text: L10n.Assist.Button.FinishRecording.title,
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
                text: L10n.Assist.Button.Listening.title,
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

    private func toggleRecording() {
        if case .recording = state {
            audioRecorder.stopRecording()
            assistService.finishSendingAudio()
            canSendAudioData = false
        } else {
            restartRecording()
        }
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
        // Recording stopped, waiting for processing
    }

    func didFailToRecord(error: any Error) {
        guard !isStopped else { return }
        if case .error = state { return }
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
        // No text display — TTS will speak the response
        state = .responding
        updateTemplateForCurrentState()
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        audioPlayer.play(url: mediaUrl)
    }

    func didReceiveError(code: String, message: String) {
        Current.Log.error("CarPlay Assist error [\(code)]: \(message)")
        state = .error(message)
        updateTemplateForCurrentState()
    }
}

// MARK: - AudioPlayerDelegate

@available(iOS 16.0, *)
extension CarPlayAssistSession: AudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AudioPlayer) {
        guard !isStopped else { return }
        if assistService.shouldStartListeningAgainAfterPlaybackEnd {
            assistService.resetShouldStartListeningAgainAfterPlaybackEnd()
            restartRecording()
        } else {
            state = .done
            updateTemplateForCurrentState()
        }
    }

    func volumeIsZero() {
        guard !isStopped else { return }
        if assistService.shouldStartListeningAgainAfterPlaybackEnd {
            assistService.resetShouldStartListeningAgainAfterPlaybackEnd()
            restartRecording()
        } else {
            state = .done
            updateTemplateForCurrentState()
        }
    }
}
