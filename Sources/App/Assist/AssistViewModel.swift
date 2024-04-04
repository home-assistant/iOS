import AVFoundation
import Foundation
import HAKit
import Shared

final class AssistViewModel: NSObject, ObservableObject {
    @Published var chatItems: [AssistChatItem] = []
    @Published var pipelines: [Pipeline] = []
    @Published var preferredPipelineId: String = ""
    @Published var showScreenLoader = false
    @Published var inputText = ""
    @Published var isRecording = false
    @Published var showPipelineErrorAlert = false

    private var server: Server
    private var audioRecorder: AudioRecorderProtocol
    private var audioPlayer: AudioPlayerProtocol
    private var assistService: AssistServiceProtocol
    private(set) var autoStartRecording: Bool
    private(set) var audioTask: Task<Void, Error>?

    private(set) var canSendAudioData = false

    init(
        server: Server,
        preferredPipelineId: String = "",
        audioRecorder: AudioRecorderProtocol,
        audioPlayer: AudioPlayerProtocol,
        assistService: AssistServiceProtocol,
        autoStartRecording: Bool
    ) {
        self.server = server
        self.preferredPipelineId = preferredPipelineId
        self.audioRecorder = audioRecorder
        self.audioPlayer = audioPlayer
        self.assistService = assistService
        self.autoStartRecording = autoStartRecording
        super.init()

        self.audioRecorder.delegate = self
        self.assistService.delegate = self
    }

    @MainActor
    func onAppear() {
        AssistSession.shared.delegate = self
        checkForAutoRecordingAndStart()
        fetchPipelines()
    }

    func onDisappear() {
        audioRecorder.stopRecording()
        audioPlayer.pause()
        audioTask?.cancel()
    }

    @MainActor
    func assistWithText() {
        audioPlayer.pause()
        stopStreaming()

        guard !inputText.isEmpty else { return }
        guard !pipelines.isEmpty, !preferredPipelineId.isEmpty else {
            fetchPipelines()
            return
        }

        assistService.assist(source: .text(input: inputText, pipelineId: preferredPipelineId))

        appendToChat(.init(content: inputText, itemType: .input))
        inputText = ""
    }

    @MainActor
    func assistWithAudio() {
        audioPlayer.pause()

        if isRecording {
            stopStreaming()
            return
        }

        // Remove text from input to make animation look better
        inputText = ""

        audioRecorder.startRecording()

        assistService.assist(
            source: .audio(
                pipelineId: preferredPipelineId,
                audioSampleRate: audioRecorder.audioSampleRate
            )
        )
    }

    private func replaceAssistService(server: Server) {
        assistService = AssistService(server: server)
        assistService.delegate = self
    }

    @MainActor
    private func appendToChat(_ item: AssistChatItem) {
        chatItems.append(item)
    }

    @MainActor
    private func fetchPipelines() {
        showScreenLoader = true
        assistService.fetchPipelines { [weak self] response in
            self?.showScreenLoader = false
            guard let self, let response else {
                self?.showPipelineError()
                return
            }
            if preferredPipelineId.isEmpty {
                preferredPipelineId = response.preferredPipeline
            }
            pipelines = response.pipelines
        }
    }

    func stopStreaming() {
        isRecording = false
        canSendAudioData = false
        audioRecorder.stopRecording()
        assistService.finishSendingAudio()
        Current.Log.info("Stop recording audio for Assist")
    }

    private func checkForAutoRecordingAndStart() {
        if autoStartRecording {
            autoStartRecording = false
            audioTask = Task {
                await assistWithAudio()
            }
        }
    }

    private func showPipelineError() {
        DispatchQueue.main.async { [weak self] in
            self?.showPipelineErrorAlert = true
        }
    }

    private func prefixStringToData(prefix: String, data: Data) -> Data {
        guard let prefixData = prefix.data(using: .utf8) else {
            return data
        }
        return prefixData + data
    }
}

extension AssistViewModel: AudioRecorderDelegate {
    func didOutputSample(data: Data) {
        guard canSendAudioData else { return }
        assistService.sendAudioData(data)
    }

    func didStartRecording() {
        isRecording = true
    }

    func didStopRecording() {
        isRecording = false
    }
}

extension AssistViewModel: AssistServiceDelegate {
    func didReceiveEvent(_ event: AssistEvent) {
        if event == .runEnd, isRecording {
            stopStreaming()
        }
    }

    @MainActor
    func didReceiveSttContent(_ content: String) {
        appendToChat(.init(content: content, itemType: .input))
    }

    @MainActor
    func didReceiveIntentEndContent(_ content: String) {
        appendToChat(.init(content: content, itemType: .output))
    }

    func didReceiveGreenLightForAudioInput() {
        canSendAudioData = true
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        audioPlayer.play(url: mediaUrl)
    }
}

extension AssistViewModel: AssistSessionDelegate {
    func didRequestNewSession(_ context: AssistSessionContext) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if context.server != server {
                server = server
                replaceAssistService(server: context.server)
            }
            preferredPipelineId = context.pipelineId
            autoStartRecording = context.autoStartRecording
            onAppear()
        }
    }
}
