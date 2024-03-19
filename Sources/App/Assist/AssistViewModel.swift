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

    private let connection: HAConnection
    private let server: Server
    private var audioRecorder: AudioRecorderProtocol
    private var audioPlayer: AudioPlayerProtocol

    private var sttBinaryHandlerId: UInt8?
    private var cancellable: HACancellable?
    private var canSendAudioData = false

    init(
        server: Server,
        preferredPipelineId: String = "",
        audioRecorder: AudioRecorderProtocol,
        audioPlayer: AudioPlayerProtocol
    ) {
        self.server = server
        self.connection = Current.api(for: server).connection
        self.preferredPipelineId = preferredPipelineId
        self.audioRecorder = audioRecorder
        self.audioPlayer = audioPlayer
        super.init()

        connection.delegate = self
        self.audioRecorder.delegate = self
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @MainActor
    func onAppear() {
        fetchPipelines()
    }

    func onDisappear() {
        cancellable?.cancel()
        connection.disconnect()
        audioRecorder.stopRecording()
        audioPlayer.pause()
    }

    private func handleAssistEvent(data: AssistResponse, cancellable: HACancellable) {
        Current.Log.info("Assist stage: \(data.type.rawValue)")
        Current.Log.info("Assist data: \(String(describing: data.data))")
        debugAppendChatMessage(data.type.rawValue)

        switch data.type {
        case .runStart:
            guard let sttBinaryHandlerId = data.data?.runnerData?.sttBinaryHandlerId else {
                Current.Log.error("No sttBinaryHandlerId on runStart")
                return
            }
            Current.Log.info("sttBinaryHandlerId: \(sttBinaryHandlerId)")
            self.sttBinaryHandlerId = UInt8(sttBinaryHandlerId)
        case .runEnd:
            stopStreaming()
            cancellable.cancel()
        case .wakeWordStart:
            break
        case .wakeWordEnd:
            break
        case .sttStart:
            canSendAudioData = true
        case .sttVadStart:
            break
        case .sttVadEnd:
            stopStreaming()
        case .sttEnd:
            appendToChat(.init(content: data.data?.sttOutput?.text ?? "Unknown", itemType: .input))
        case .intentStart:
            break
        case .intentEnd:
            appendToChat(.init(
                content: data.data?.intentOutput?.response?.speech.plain.speech ?? "Unknown",
                itemType: .output
            ))
        case .ttsStart:
            break
        case .ttsEnd:
            guard let mediaUrlPath = data.data?.ttsOutput?.urlPath else { return }
            let mediaUrl = server.info.connection.activeURL().appendingPathComponent(mediaUrlPath)
            audioPlayer.play(url: mediaUrl)
        case .error:
            Current.Log.error("Received error while interating with Assist: \(data)")
            appendToChat(.init(content: "Error: \(data)", itemType: .error))
            cancellable.cancel()
        }
    }

    @MainActor
    func assistWithText() {
        audioPlayer.pause()
        cancellable?.cancel()
        stopStreaming()

        guard !inputText.isEmpty else { return }
        guard !pipelines.isEmpty, !preferredPipelineId.isEmpty else {
            fetchPipelines()
            return
        }
        connection.subscribe(to: AssistRequests.assistByTextTypedSubscription(
            preferredPipelineId: preferredPipelineId,
            inputText: inputText
        )) { [weak self] cancellable, data in
            guard let self else { return }
            self.cancellable = cancellable
            handleAssistEvent(data: data, cancellable: cancellable)
        }
        appendToChat(.init(id: UUID().uuidString, content: inputText, itemType: .input))
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

        connection.subscribe(to: AssistRequests.assistByVoiceTypedSubscription(
            preferredPipelineId: preferredPipelineId,
            audioSampleRate: audioRecorder.audioSampleRate
        )) { [weak self] cancellable, data in
            guard let self else { return }
            self.cancellable = cancellable
            handleAssistEvent(data: data, cancellable: cancellable)
        }
    }

    private func appendToChat(_ item: AssistChatItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            chatItems.append(item)
        }
    }

    @MainActor
    private func fetchPipelines() {
        showScreenLoader = true
        connection.send(AssistRequests.fetchPipelinesTypedRequest) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(response):
                if preferredPipelineId.isEmpty {
                    preferredPipelineId = response.preferredPipeline
                }
                pipelines = response.pipelines
            case let .failure(error):
                Current.Log.error("Failed to fetch Assist pipelines: \(error.localizedDescription)")
            }
            showScreenLoader = false
        }
    }

    func stopStreaming() {
        isRecording = false
        canSendAudioData = false
        audioRecorder.stopRecording()
        finishSendingAudio()
        sttBinaryHandlerId = nil
        Current.Log.info("Stop recording audio for Assist")
    }

    private func prefixStringToData(prefix: String, data: Data) -> Data {
        guard let prefixData = prefix.data(using: .utf8) else {
            return data
        }
        return prefixData + data
    }

    private func debugAppendChatMessage(_ message: String) {
        #if DEBUG
        appendToChat(.init(content: "DEBUG: \(message)", itemType: .info))
        #endif
    }
}

extension AssistViewModel: HAConnectionDelegate {
    func connection(_ connection: HAConnection, didTransitionTo state: HAConnectionState) {
        debugAppendChatMessage("\(state)")
    }
}

extension AssistViewModel: AudioRecorderDelegate {
    func didOutputSample(data: Data) {
        guard canSendAudioData, let sttBinaryHandlerId else { return }
        _ = self.connection.send(.init(
            type: .sttData(.init(sttBinaryHandlerId: sttBinaryHandlerId)),
            data: ["audioData": data.base64EncodedString()]
        ))
    }

    func didStartRecording() {
        isRecording = true
    }

    func didStopRecording() {
        isRecording = false
    }

    /// Sends stt binary handler id as a single byte to tell Assist pipeline that audio session is over
    private func finishSendingAudio() {
        guard canSendAudioData,
              let sttBinaryHandlerId else { return }
        _ = connection.send(.init(type: .sttData(.init(sttBinaryHandlerId: sttBinaryHandlerId))))
    }
}
