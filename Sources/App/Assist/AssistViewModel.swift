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
    @Published var showError = false
    @Published var errorMessage = ""

    private var server: Server
    private var audioRecorder: AudioRecorderProtocol
    private var audioPlayer: AudioPlayerProtocol
    private var assistService: AssistServiceProtocol
    private(set) var autoStartRecording: Bool
    private(set) var audioTask: Task<Void, Error>?
    private(set) var routineTask: Task<Void, Error>?

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
    func initialRoutine() {
        AssistSession.shared.delegate = self
        routineTask?.cancel()
        routineTask = Task.detached { [weak self] in
            await self?.fetchPipelines()
            self?.checkForAutoRecordingAndStart()
        }
    }

    func onDisappear() {
        audioRecorder.stopRecording()
        audioPlayer.pause()
        audioTask?.cancel()
        routineTask?.cancel()
    }

    @MainActor
    func assistWithText() {
        audioPlayer.pause()
        stopStreaming()
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
        // Wait until green light from recorder delegate 'didStartRecording'
    }

    private func startAssistAudioPipeline(audioSampleRate: Double) {
        assistService.assist(
            source: .audio(
                pipelineId: preferredPipelineId,
                audioSampleRate: audioSampleRate
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
    private func fetchPipelines() async {
        showScreenLoader = true
        await withCheckedContinuation { [weak self] continuation in
            self?.assistService.fetchPipelines { [weak self] response in
                self?.showScreenLoader = false
                guard let self, let response else {
                    self?.showError(message: L10n.Assist.Error.pipelinesResponse)
                    continuation.resume()
                    return
                }
                if preferredPipelineId.isEmpty {
                    preferredPipelineId = response.preferredPipeline
                }
                pipelines = response.pipelines
                continuation.resume()
            }
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

    private func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
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
    func didFailToRecord(error: any Error) {
        showError(message: error.localizedDescription)
    }

    func didOutputSample(data: Data) {
        guard canSendAudioData else { return }
        assistService.sendAudioData(data)
    }

    func didStartRecording(with sampleRate: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
            #if DEBUG
            self?.appendToChat(.init(content: "didStartRecording(with sampleRate: \(sampleRate)", itemType: .info))
            #endif
        }
        startAssistAudioPipeline(audioSampleRate: sampleRate)
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

    @MainActor
    func didReceiveError(code: String, message: String) {
        Current.Log.error("Assist error: \(code)")
        appendToChat(.init(content: message, itemType: .error))
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
            initialRoutine()
        }
    }
}
