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
    @Published var availableAudioDevices: [AVCaptureDevice] = []
    @Published var selectedAudioDeviceId: String = "" {
        didSet {
            if let device = availableAudioDevices.first(where: { $0.uniqueID == selectedAudioDeviceId }) {
                audioRecorder.selectedAudioDevice = device
                Current.Log.info("Selected audio device changed to: \(device.localizedName)")
            }
        }
    }

    private var server: Server
    private var audioRecorder: AudioRecorderProtocol
    private var audioPlayer: AudioPlayerProtocol
    private var assistService: AssistServiceProtocol
    private(set) var autoStartRecording: Bool

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

        if ["last_used", "preferred"].contains(preferredPipelineId) {
            self.preferredPipelineId = ""
        }
        
        // Load available audio devices
        #if targetEnvironment(macCatalyst)
        loadAvailableAudioDevices()
        #endif
    }

    func initialRoutine() {
        AssistSession.shared.delegate = self

        loadCachedPipelines()

        if pipelines.isEmpty {
            fetchPipelines { [weak self] in
                self?.checkForAutoRecordingAndStart()
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

    func assistWithText() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        audioPlayer.pause()
        stopStreaming()
        assistService.assist(source: .text(input: inputText, pipelineId: preferredPipelineId))
        appendToChat(.init(content: inputText, itemType: .input))
        inputText = ""
    }

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
                pipelineId: preferredPipelineId.isEmpty ? pipelines.first?.id : preferredPipelineId,
                audioSampleRate: audioSampleRate
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
            if chatItems.last?.itemType == .typing {
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

    func stopStreaming() {
        isRecording = false
        canSendAudioData = false

        // Stop traditional audio recording
        audioRecorder.stopRecording()
        assistService.finishSendingAudio()

        Current.Log.info("Stop recording audio for Assist")
    }

    private func checkForAutoRecordingAndStart() {
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

    private func startRecordingAgainIfNeeded() {
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
    
    #if targetEnvironment(macCatalyst)
    private func loadAvailableAudioDevices() {
        availableAudioDevices = audioRecorder.availableAudioDevices()
        
        // Set default device to the system default (first in list or default audio device)
        if let defaultDevice = AVCaptureDevice.default(for: .audio) {
            selectedAudioDeviceId = defaultDevice.uniqueID
            audioRecorder.selectedAudioDevice = defaultDevice
            Current.Log.info("Default audio device set to: \(defaultDevice.localizedName)")
        } else if let firstDevice = availableAudioDevices.first {
            selectedAudioDeviceId = firstDevice.uniqueID
            audioRecorder.selectedAudioDevice = firstDevice
            Current.Log.info("Default audio device set to first available: \(firstDevice.localizedName)")
        }
    }
    #endif

    // MARK: - On-Device Transcription Methods
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
            stopStreaming()
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

extension AssistViewModel: AudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AudioPlayer) {
        startRecordingAgainIfNeeded()
    }

    func volumeIsZero() {
        startRecordingAgainIfNeeded()
    }
}
