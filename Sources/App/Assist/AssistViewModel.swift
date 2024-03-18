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

    private var captureSession: AVCaptureSession?
    private let connection: HAConnection
    private let server: Server

    private var sttBinaryHandlerId: UInt8?
    private var cancellable: HACancellable?

    private var debugAudioHexString = ""
    private var canSendAudioData = false
    private var audioSampleRate: Double = 16000
    private let player = AVPlayer()

    init(server: Server, preferredPipelineId: String = "") {
        self.server = server
        self.connection = Current.api(for: server).connection
        self.preferredPipelineId = preferredPipelineId
        super.init()
        connection.delegate = self
        registerForRecordingNotifications()
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
        captureSession?.stopRunning()
        player.pause()
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
            playTTS(url: mediaUrl)
        case .error:
            Current.Log.error("Received error while interating with Assist: \(data)")
            appendToChat(.init(content: "Error: \(data)", itemType: .error))
            cancellable.cancel()
        }
    }

    @MainActor
    func assistWithText() {
        player.pause()
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
        player.pause()

        if isRecording {
            stopStreaming()
            return
        }

        // Remove text from input to make animation look better
        inputText = ""

        setupAudioRecorder()
        guard let captureSession else { return }
        DispatchQueue.global().async { [weak self] in
            captureSession.startRunning()
            self?.isRecording = true
        }

        connection.subscribe(to: AssistRequests.assistByVoiceTypedSubscription(
            preferredPipelineId: preferredPipelineId,
            audioSampleRate: audioSampleRate
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

    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        guard let captureDevice = AVCaptureDevice.default(for: .audio) else {
            Current.Log.error("Failed to get capture device to record audio for Assist")
            return
        }

        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setPreferredSampleRate(16000)
            try audioSession.setPreferredOutputNumberOfChannels(1)

            try audioSession.setActive(true)
            let audioInput = try AVCaptureDeviceInput(device: captureDevice)

            captureSession = AVCaptureSession()
            captureSession?.addInput(audioInput)

            Current.Log.info("Audio sample rate: \(audioSession.sampleRate)")
            audioSampleRate = audioSession.sampleRate

            let audioOutput = AVCaptureAudioDataOutput()

            audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))
            captureSession?.addOutput(audioOutput)
        } catch {
            let message = "Error starting audio streaming: \(error.localizedDescription)"
            Current.Log.error(message)
            debugAppendChatMessage(message)
            stopStreaming()
        }
    }

    func stopStreaming() {
        isRecording = false
        canSendAudioData = false
        captureSession?.stopRunning()

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

    private func registerForRecordingNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidStartRunning),
            name: .AVCaptureSessionDidStartRunning,
            object: captureSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidStopRunning),
            name: .AVCaptureSessionDidStopRunning,
            object: captureSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: .AVCaptureSessionRuntimeError,
            object: captureSession
        )
    }

    @objc private func sessionDidStartRunning(notification: Notification) {
        isRecording = true
    }

    @objc private func sessionDidStopRunning(notification: Notification) {
        isRecording = false
    }

    @objc private func sessionRuntimeError(notification: Notification) {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            let message = "AVCaptureSession runtime error: \(error)"
            debugAppendChatMessage(message)
            Current.Log.error(message)
        }
    }

    private func playTTS(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
    }
}

extension AssistViewModel: HAConnectionDelegate {
    func connection(_ connection: HAConnection, didTransitionTo state: HAConnectionState) {
        debugAppendChatMessage("\(state)")
    }
}

extension AssistViewModel: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard canSendAudioData,
              let sttBinaryHandlerId,
              let data = sampleBuffer.audioSamples() else {
            Current.Log.error("Failed to send audio samples to websocket connection")
            return
        }
        _ = self.connection.send(.init(
            type: .sttData(sttBinaryHandlerId),
            data: ["audioData": data.base64EncodedString()]
        ))
    }

    /// Sends stt binary handler id as a single byte to tell Assist pipeline that audio session is over
    private func finishSendingAudio() {
        guard canSendAudioData,
              let sttBinaryHandlerId else { return }
        _ = connection.send(.init(type: .sttData(sttBinaryHandlerId)))
    }
}
