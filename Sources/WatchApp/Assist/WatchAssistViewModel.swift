import Foundation
import PromiseKit
import Shared

struct WatchPipeline {
    let id: String
    let name: String
}

final class WatchAssistViewModel: ObservableObject {
    private enum Constants {
        /// The orb level rises fast so every syllable registers, and falls slower so it settles
        /// instead of flickering between words.
        static let audioLevelAttack: Double = 0.8
        static let audioLevelRelease: Double = 0.25
        /// Below 1: lifts quiet speech up the scale, so normal talking moves the orb noticeably.
        static let audioLevelCurve: Double = 0.65
        /// A press released sooner than this is a tap, not a hold: the recording goes on and waits
        /// for the tap that sends it, as it did before push-to-talk.
        static let tapDuration: TimeInterval = 0.3
    }

    enum State {
        case idle
        case recording
        case loading
        case waitingForPipelineResponse
    }

    /// What ends the recording in progress and sends it.
    enum RecordingSubmission {
        /// A tap: recordings started for the user (home screen, complication, Double Tap) keep
        /// this flow, since no finger is on the screen to lift.
        case tap
        /// Lifting the finger: the user is holding the chat screen to ask something else.
        case release
    }

    @Published var chatItems: [AssistChatItem] = []
    @Published var state: State = .idle
    @Published var recordingSubmission: RecordingSubmission = .tap
    /// When the finger landed for the push-to-talk recording in progress; `nil` outside one.
    private var pushToTalkBegan: Date?
    /// Flips the recording to release-to-send once the press has lasted long enough to be a hold.
    private var holdRecognition: DispatchWorkItem?
    /// Normalized microphone input level (0...1) driving the voice orb while recording
    @Published var audioLevel: Double = 0
    @Published var showChatLoader = false
    private var timer: Timer?

    private let audioRecorder: any WatchAudioRecorderProtocol
    private let audioPlayer: any AudioPlayerProtocol
    private let speechSynthesizer: any WatchSpeechSynthesizing
    private let immediateCommunicatorService: ImmediateCommunicatorService
    private let runtimeSessions: WatchExtendedRuntimeSessionHolding
    private var isHoldingRuntimeSession = false
    /// Written prompt of an Assist prompt item: the session sends it instead of listening. `nil`
    /// for a regular voice session.
    private let prompt: String?

    @Published var assistService: WatchAssistService

    init(
        assistService: WatchAssistService,
        audioRecorder: any WatchAudioRecorderProtocol,
        audioPlayer: any AudioPlayerProtocol,
        speechSynthesizer: any WatchSpeechSynthesizing = WatchSpeechSynthesizer(),
        immediateCommunicatorService: ImmediateCommunicatorService,
        runtimeSessions: WatchExtendedRuntimeSessionHolding = WatchExtendedRuntimeSessionManager.shared,
        prompt: String? = nil
    ) {
        self.audioRecorder = audioRecorder
        self.immediateCommunicatorService = immediateCommunicatorService
        self.runtimeSessions = runtimeSessions
        self.assistService = assistService
        self.audioPlayer = audioPlayer
        self.speechSynthesizer = speechSynthesizer
        self.prompt = prompt
        audioRecorder.delegate = self
        immediateCommunicatorService.addObserver(.init(delegate: self))
    }

    deinit {
        endRoutine()
    }

    func initialRoutine() {
        if let prompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty {
            sendPrompt(prompt)
        } else {
            assist()
        }
    }

    /// Send an Assist prompt item's text through the pipeline. The prompt itself is echoed into the
    /// chat straight away — a text run produces no speech-to-text event, so nothing else would show
    /// what was asked.
    private func sendPrompt(_ prompt: String) {
        guard assistService.deviceReachable else {
            state = .idle
            showUnreacheableMessage()
            return
        }
        appendChatItem(.init(content: prompt, itemType: .input))
        state = .waitingForPipelineResponse
        assistService.assist(text: prompt) { [weak self] error in
            guard let error else { return }
            Current.Log.error("Failed to send Assist prompt from watch: \(error.localizedDescription)")
            self?.appendChatItem(.init(content: L10n.Assist.Watch.NotReachable.title, itemType: .error))
            self?.updateState(state: .idle)
        }
    }

    /// (Re)subscribe to phone responses. Called on every appearance: `endRoutine()` unsubscribes
    /// when the view disappears (volume screen push, dismissal), so a view model that returns to
    /// the screen must register again or it stays deaf to STT/intent/TTS responses. Remove first
    /// so repeated appearances can't stack duplicate deliveries.
    func reconnectObserver() {
        immediateCommunicatorService.removeObserver(self)
        immediateCommunicatorService.addObserver(.init(delegate: self))
    }

    func beginExtendedRuntime() {
        guard !isHoldingRuntimeSession else { return }
        isHoldingRuntimeSession = true
        runtimeSessions.begin(.assist)
    }

    func endRoutine() {
        finishPushToTalkPress()
        stopRecording()
        speechSynthesizer.stop()
        assistService.endRoutine()
        timer?.invalidate()
        immediateCommunicatorService.removeObserver(self)
        endExtendedRuntime()
    }

    private func endExtendedRuntime() {
        guard isHoldingRuntimeSession else { return }
        isHoldingRuntimeSession = false
        runtimeSessions.end(.assist)
    }

    /// Tap-to-send flow: starts a recording, or sends the one in progress.
    func assist() {
        startRecording()
    }

    /// Push-to-talk: the user pressed the chat screen. Nothing happens over a recording in
    /// progress, so a tap-to-send recording is not turned into one that ends on release.
    func beginPushToTalk() {
        guard ![.recording, .loading].contains(state) else { return }
        pushToTalkBegan = Current.date()
        // The recording starts as tap-to-send: a quick tap keeps that flow, as before push-to-talk,
        // and only a press that lasts becomes release-to-send, so a tap never flashes the hint.
        startRecording()
        let holdRecognition = DispatchWorkItem { [weak self] in
            guard let self, pushToTalkBegan != nil, state == .recording else { return }
            recordingSubmission = .release
        }
        self.holdRecognition = holdRecognition
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.tapDuration, execute: holdRecognition)
    }

    /// Push-to-talk: the finger lifted. A hold sends the recording the press started; a quick tap
    /// leaves it going as a tap-to-send recording. A recording started any other way is never
    /// touched here.
    func endPushToTalk() {
        guard let pushToTalkBegan else { return }
        finishPushToTalkPress()
        let isTap = Current.date().timeIntervalSince(pushToTalkBegan) < Constants.tapDuration
        guard !isTap, state == .recording else { return }
        stopRecording()
    }

    /// Push-to-talk: the press was taken over by something else, such as a scroll of the chat.
    /// The user was not asking anything, so the recording is dropped rather than sent.
    func cancelPushToTalk() {
        guard pushToTalkBegan != nil else { return }
        finishPushToTalkPress()
        audioRecorder.cancelRecording()
    }

    private func finishPushToTalkPress() {
        pushToTalkBegan = nil
        holdRecognition?.cancel()
        holdRecognition = nil
    }

    private func startRecording() {
        if assistService.deviceReachable {
            // The recorder toggles: over a recording in progress this call sends it, and how that
            // recording ends still describes it until it is over.
            if state != .recording {
                recordingSubmission = .tap
            }
            // Extra message just to wake up iPhone from the background
            Communicator.shared.send(HAWatchConnectivity.ImmediateMessage(identifier: "wakeup"))
            audioRecorder.startRecording()
        } else {
            state = .idle
            showUnreacheableMessage()
        }
    }

    func stopRecording() {
        audioRecorder.stopRecording()
    }

    func startPingPong() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerAction()
        }
    }

    func stopPingPong() {
        timer?.invalidate()
    }

    private func timerAction() {
        Current.Log.verbose("Ping iPhone")
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.ping.rawValue,
            reply: { [immediateCommunicatorService] pong in
                Current.Log.verbose("Pong from iPhone")
                DispatchQueue.main.async {
                    immediateCommunicatorService.evaluatePong(pong)
                }
            }
        ))
    }

    private func showUnreacheableMessage() {
        chatItems.append(.init(content: L10n.Assist.Watch.NotReachable.title, itemType: .error))
    }

    private func showChatLoader(show: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.showChatLoader = show
        }
    }

    private func updateState(state: State) {
        DispatchQueue.main.async { [weak self] in
            self?.state = state
        }
    }

    private func sendAudioData(audioURL: URL, audioSampleRate: Double) {
        guard assistService.deviceReachable else {
            showUnreacheableMessage()
            return
        }
        showChatLoader(show: true)
        assistService.assist(audioURL: audioURL, sampleRate: audioSampleRate) { [weak self] error in
            if let error {
                Current.Log.error("Failed to assist from watch error: \(error.localizedDescription)")
                self?.updateState(state: .idle)
                #if DEBUG
                self?.appendChatItem(.init(content: error.localizedDescription, itemType: .info))
                #endif
            } else {
                Current.Log.info("sendAudioData succeeded")
            }
        }
    }

    func appendChatItem(_ item: AssistChatItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if chatItems.last?.itemType == .typing {
                chatItems.removeLast()
            }
            chatItems.append(item)
            if item.itemType == .input {
                chatItems.append(.init(content: "", itemType: .typing))
            }
            showChatLoader = false
        }
    }

    private func runInMainThread(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            completion()
        }
    }
}

extension WatchAssistViewModel: @preconcurrency WatchAudioRecorderDelegate {
    @MainActor
    func didStartRecording() {
        runInMainThread { [weak self] in
            self?.state = .recording
        }
    }

    @MainActor
    func didStopRecording() {
        runInMainThread { [weak self] in
            self?.state = .waitingForPipelineResponse
            self?.audioLevel = 0
        }
    }

    func didCancelRecording() {
        runInMainThread { [weak self] in
            self?.state = .idle
            self?.audioLevel = 0
        }
    }

    func didUpdateAudioLevel(_ level: Float) {
        runInMainThread { [weak self] in
            guard let self, state == .recording else { return }
            let shaped = pow(Double(level), Constants.audioLevelCurve)
            let smoothing = shaped > audioLevel ? Constants.audioLevelAttack : Constants.audioLevelRelease
            audioLevel = audioLevel * (1 - smoothing) + shaped * smoothing
        }
    }

    @MainActor
    func didFinishRecording(audioURL: URL, audioSampleRate: Double) {
        sendAudioData(audioURL: audioURL, audioSampleRate: audioSampleRate)
        runInMainThread { [weak self] in
            self?.state = .waitingForPipelineResponse
        }
    }

    func didFailRecording(error: any Error) {
        Current.Log.error("Failed to record Assist audio in watch App: \(error.localizedDescription)")
        appendChatItem(.init(content: error.localizedDescription, itemType: .error))
        runInMainThread { [weak self] in
            self?.state = .idle
            self?.audioLevel = 0
        }
    }
}

extension WatchAssistViewModel: ImmediateCommunicatorServiceDelegate {
    func didReceiveChatItem(_ item: AssistChatItem) {
        appendChatItem(item)
        // The intent response ends the round-trip. Returning to idle also stops the keep-alive
        // ping-pong (see `startPingPong`), which exists only to keep the phone app awake while the
        // pipeline runs — it used to keep pinging for as long as the screen stayed open.
        if item.itemType == .output {
            updateState(state: .idle)
        }
    }

    func didReceiveTTS(url: URL) {
        let server = assistService.server
        if server == nil {
            Current.Log.error("Watch Assist could not resolve the session's server, TTS playback will stream")
        }
        audioPlayer.play(url: url, server: server)
    }

    func didReceiveOnDeviceTTS(_ payload: AssistOnDeviceTTSPayload) {
        speechSynthesizer.speak(payload)
    }

    func didReceiveError(code: String, message: String) {
        Current.Log.error("Watch Assist error: \(code)")
        appendChatItem(.init(content: message, itemType: .error))
        stopRecording()
        // A failed round-trip is over too: return to idle so the keep-alive ping-pong stops.
        updateState(state: .idle)
    }
}
