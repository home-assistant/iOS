import AVFoundation
import Foundation
import GRDB
import HAKit
import Shared

final class AssistViewModel: NSObject, ObservableObject {
    @Published var chatItems: [AssistChatItem] = []
    @Published var pipelines: [Pipeline] = []
    @Published var preferredPipelineId: String = "" {
        didSet {
            if !oldValue.isEmpty, oldValue != preferredPipelineId {
                onPipelineChanged()
            }
        }
    }

    @Published var inputText = ""
    @Published var isRecording = false
    @Published var showError = false
    @Published var focusOnInput = false
    @Published var errorMessage = ""
    @Published var configuration: AssistConfiguration

    private var server: Server
    private var audioRecorder: AudioRecorderProtocol
    private var audioPlayer: AudioPlayerProtocol
    private var assistService: AssistServiceProtocol
    private(set) var autoStartRecording: Bool

    private(set) var canSendAudioData = false
    private var configObservationCancellable: AnyDatabaseCancellable?
    private var speechTranscriber: Any?

    // Key for TTS mute setting (matches @AppStorage key in AssistSettingsView)
    static let ttsMuteKey = "assistMuteTTS"

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
        self.configuration = AssistConfiguration.config
        super.init()

        self.audioRecorder.delegate = self
        self.assistService.delegate = self

        if ["last_used", "preferred"].contains(preferredPipelineId) {
            self.preferredPipelineId = ""
        }
    }

    @MainActor func initialRoutine() {
        AssistSession.shared.delegate = self

        loadCachedPipelines()

        if pipelines.isEmpty {
            fetchPipelines { [weak self] in
                Task { @MainActor in self?.checkForAutoRecordingAndStart() }
            }
        } else {
            checkForAutoRecordingAndStart()
            fetchPipelines()
        }
    }

    func onDisappear() {
        audioRecorder.stopRecording()
        audioPlayer.pause()
    }

    @MainActor func assistWithText() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        audioPlayer.pause()
        stopStreaming()
        assistService.assist(source: .text(input: inputText, pipelineId: preferredPipelineId, expectTTS: false))
        appendToChat(.init(content: inputText, itemType: .input))
        inputText = ""
    }

    @MainActor func assistWithTextExpectingTTS() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        audioPlayer.pause()
        stopStreaming()
        assistService.assist(source: .text(input: inputText, pipelineId: preferredPipelineId, expectTTS: !configuration.muteTTS))
        appendToChat(.init(content: inputText, itemType: .input))
        inputText = ""
    }

    @MainActor func assistWithAudio() {
        if configuration.enableOnDeviceSTT {
            if isRecording {
                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    assistWithText()
                } else {
                    stopStreaming()
                }
                return
            }
            inputText = ""
            startOnDeviceTranscription()
        } else {
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
    }

    func subscribeForConfigChanges() {
        let observation = ValueObservation.tracking { db in
            try AssistConfiguration.fetchOne(db, key: AssistConfiguration.singletonID)
        }

        configObservationCancellable = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("Failed to observe AssistConfiguration changes: \(error)")
            },
            onChange: { [weak self] newConfiguration in
                guard let self else { return }
                if let newConfiguration {
                    configuration = newConfiguration
                    Current.Log.info("AssistConfiguration updated: \(newConfiguration)")
                }
            }
        )
    }

    private func startAssistAudioPipeline(audioSampleRate: Double) {
        assistService.assist(
            source: .audio(
                pipelineId: preferredPipelineId.isEmpty ? pipelines.first?.id : preferredPipelineId,
                audioSampleRate: audioSampleRate,
                tts: !configuration.muteTTS
            )
        )
    }

    private func replaceAssistService(server: Server) {
        assistService = AssistService(server: server)
        assistService.delegate = self
    }

    private func appendToChat(_ item: AssistChatItem) {
        if item.itemType == .output {
            /*
             Always replace last output chat item in case a new one is
             appended in sequence, avoiding duplicate content in case the pipeline supports stream responses
             */
            if [.output, .typing].contains(chatItems.last?.itemType) {
                chatItems.removeLast()
            }
        } else {
            if [.typing, .pending].contains(chatItems.last?.itemType) {
                chatItems.removeLast()
            }
        }

        chatItems.append(item)
        if item.itemType == .input {
            chatItems.append(.init(content: "", itemType: .typing))
        }
    }

    private func fetchPipelines(completion: (() -> Void)? = nil) {
        assistService.fetchPipelines { [weak self] _ in
            guard let self else {
                self?.showError(message: L10n.Assist.Error.pipelinesResponse)
                return
            }

            // Fetch pipelines method already saves new values in database
            // loading cache now
            loadCachedPipelines()
            completion?()
        }
    }

    private func loadCachedPipelines() {
        do {
            if let cachedPipelineConfig = try Current.database().read({ db in
                try AssistPipelines
                    .filter(Column(DatabaseTables.AssistPipelines.serverId.rawValue) == server.identifier.rawValue)
                    .fetchOne(db)
            }) {
                if preferredPipelineId.isEmpty {
                    setPreferredPipelineId(cachedPipelineConfig.preferredPipeline)
                }
                pipelines = cachedPipelineConfig.pipelines
            } else {
                Current.Log.error("Error loading cached pipelines: No cache found.")
            }
        } catch {
            Current.Log.error("Error loading cached pipelines: \(error)")
        }
    }

    private func setPreferredPipelineId(_ pipelineId: String) {
        preferredPipelineId = pipelineId
    }

    @MainActor private func updatePendingTranscription(_ text: String) {
        if chatItems.last?.itemType == .pending {
            chatItems.removeLast()
        }
        if !text.isEmpty {
            chatItems.append(.init(content: text, itemType: .pending))
        }
    }

    @MainActor func stopStreaming() {
        isRecording = false
        canSendAudioData = false

        // Stop traditional audio recording
        audioRecorder.stopRecording()
        assistService.finishSendingAudio()

        if #available(iOS 17.0, *) {
            (speechTranscriber as? SpeechTranscriber)?.stopListening()
        }

        // Remove pending transcription bubble if recording stopped without submitting
        if chatItems.last?.itemType == .pending {
            chatItems.removeLast()
        }

        Current.Log.info("Stop recording audio for Assist")
    }

    @MainActor private func checkForAutoRecordingAndStart() {
        if autoStartRecording {
            Current.Log.info("Auto start recording triggered in Assist")
            autoStartRecording = false
            assistWithAudio()
        } else if Current.isCatalyst {
            focusOnInput = true
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

    @MainActor private func startRecordingAgainIfNeeded() {
        if assistService.shouldStartListeningAgainAfterPlaybackEnd {
            assistService.resetShouldStartListeningAgainAfterPlaybackEnd()
            assistWithAudio()
        }
    }

    private func onPipelineChanged() {
        // Find the pipeline name from the ID
        if let pipeline = pipelines.first(where: { $0.id == preferredPipelineId }) {
            appendToChat(.init(content: pipeline.name, itemType: .info))
            Current.Log.info("Pipeline changed to: \(pipeline.name) (\(preferredPipelineId))")
        }
    }

    // MARK: - On-Device Transcription Methods

    @MainActor private func startOnDeviceTranscription() {
        guard #available(iOS 17.0, *) else { return }

        let localeIdentifier = configuration.onDeviceSTTLocaleIdentifier
        let transcriber = localeIdentifier.map { SpeechTranscriber(localeIdentifier: $0) } ?? SpeechTranscriber()
        speechTranscriber = transcriber

        transcriber.onTranscriptUpdate = { [weak self] text, isFinal in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.inputText = text
                self.updatePendingTranscription(text)
                if isFinal {
                    self.assistWithTextExpectingTTS()
                }
            }
        }

        transcriber.onError = { [weak self] error in
            MainActor.assumeIsolated {
                guard let self, self.isRecording else { return }
                self.showError(message: error.localizedDescription)
                self.stopStreaming()
            }
        }

        transcriber.onListeningStateChange = { [weak self] listening in
            MainActor.assumeIsolated {
                guard let self, !listening else { return }
                self.isRecording = false
            }
        }

        isRecording = true

        Task {
            do {
                try await transcriber.startListening()
            } catch {
                showError(message: error.localizedDescription)
                isRecording = false
            }
        }
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
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
        }
    }
}

extension AssistViewModel: AssistServiceDelegate {
    func didReceiveStreamResponseChunk(_ content: String) {
        if let lastItemInList = chatItems.last, lastItemInList.itemType == .output {
            let newContent = lastItemInList.content + content
            appendToChat(.init(content: newContent, itemType: .output))
        } else {
            appendToChat(.init(content: content, itemType: .output))
        }
    }

    func didReceiveEvent(_ event: AssistEvent) {
        if [.sttEnd, .runEnd].contains(event), isRecording {
            Task { @MainActor in self.stopStreaming() }
        }
    }

    func didReceiveSttContent(_ content: String) {
        appendToChat(.init(content: content, itemType: .input))
    }

    func didReceiveIntentEndContent(_ content: String) {
        appendToChat(.init(content: content, itemType: .output))
    }

    func didReceiveGreenLightForAudioInput() {
        canSendAudioData = true
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        // Check if TTS is muted in settings
        let muteTTS = UserDefaults.standard.bool(forKey: Self.ttsMuteKey)

        if muteTTS {
            Current.Log.info("TTS is muted by user setting, skipping audio playback")
            // Check if we should continue the conversation (e.g., for follow-up questions)
            Task { @MainActor in self.startRecordingAgainIfNeeded() }
            return
        }

        audioPlayer.delegate = self
        audioPlayer.play(url: mediaUrl)
    }

    func didReceiveError(code: String, message: String) {
        Current.Log.error("Assist error: \(code)")
        appendToChat(.init(content: message, itemType: .error))
    }
}

extension AssistViewModel: AssistSessionDelegate {
    func didRequestNewSession(_ context: AssistSessionContext) {
        Task { @MainActor [weak self] in
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

extension AssistViewModel: AudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AudioPlayer) {
        Task { @MainActor in startRecordingAgainIfNeeded() }
    }

    func volumeIsZero() {
        Task { @MainActor in startRecordingAgainIfNeeded() }
    }
}
