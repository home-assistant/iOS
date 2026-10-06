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
        /// A press that starts a recording is a hold, sent when the finger lifts, once it lasts this
        /// long. Lifting sooner is a tap: the recording goes on until the next tap.
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
        /// A tap: recordings started by a tap on the chat screen or for the user (home screen,
        /// complication, Double Tap), since no finger is held on the screen.
        case tap
        /// Lifting the finger: the user is holding the chat screen to ask something else.
        case release
    }

    /// What lifting the finger pressing the chat screen does.
    private enum Press {
        /// The press started the recording in progress when the finger landed at this time: lifting
        /// sends it if the press was a hold, and leaves it going until the next tap otherwise.
        case startedRecording(at: Date)
        /// The press landed on a recording already in progress: lifting sends it.
        case sendsRecording
    }

    @Published var chatItems: [AssistChatItem] = []
    @Published var state: State = .idle
    @Published var recordingSubmission: RecordingSubmission = .tap
    /// The finger on the chat screen; `nil` while nothing presses it.
    private var press: Press?
    /// Shows the recording as release-to-send once the press has lasted long enough to be a hold.
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

    /// The user pressed the chat screen. Over a recording in progress the press is a tap that sends
    /// it; otherwise the press starts one.
    func beginPushToTalk(at time: Date) {
        switch state {
        case .loading:
            return
        case .recording:
            press = .sendsRecording
        case .idle, .waitingForPipelineResponse:
            press = .startedRecording(at: time)
            // The recording starts as tap-to-send: a quick tap keeps that flow, and only a press
            // that lasts becomes release-to-send, so a tap never flashes the hint.
            startRecording()
            // Only the hint waits on this: whether the press was a hold is measured from the touch
            // times when the finger lifts.
            let holdRecognition = DispatchWorkItem { [weak self] in
                guard let self, case .startedRecording? = press, state == .recording else { return }
                recordingSubmission = .release
            }
            self.holdRecognition = holdRecognition
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.tapDuration, execute: holdRecognition)
        }
    }

    /// The finger lifted. A hold sends the recording it started and a tap sends the one in progress,
    /// while the tap that starts a recording leaves it going until the next one.
    func endPushToTalk(at time: Date) {
        guard let press else { return }
        finishPushToTalkPress()
        guard state == .recording else { return }
        switch press {
        case let .startedRecording(began) where time.timeIntervalSince(began) < Constants.tapDuration:
            // The hint can be up even so, when the lift waited for the main thread to handle it.
            recordingSubmission = .tap
        case .startedRecording, .sendsRecording:
            stopRecording()
        }
    }

    /// The press was taken over by something else, such as a scroll of the chat. The user was not
    /// asking anything, so a recording the press started is dropped rather than sent, and one
    /// already in progress goes on.
    func cancelPushToTalk() {
        guard let press else { return }
        finishPushToTalkPress()
        guard case .startedRecording = press else { return }
        audioRecorder.cancelRecording()
    }

    private func finishPushToTalkPress() {
        press = nil
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

    /// The recording ended, by hand or because the iPhone heard the user stop speaking.
    private func submitRecording() {
        showChatLoader(show: true)
        assistService.submitAudio { [weak self] error in
            self?.didFailToSendAudio(error)
        }
    }

    private func didFailToSendAudio(_ error: Error) {
        Current.Log.error("Failed to send Assist audio from watch: \(error.localizedDescription)")
        // A recording still going has nowhere to go any more.
        audioRecorder.cancelRecording()
        appendChatItem(.init(content: L10n.Assist.Watch.NotReachable.title, itemType: .error))
        updateState(state: .idle)
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
    func didStartRecording(sampleRate: Double) {
        // Set straight away rather than on a later turn of the main queue: a press that started the
        // recording can lift while the recorder is still being set up, and lifting must find it.
        state = .recording
        // The iPhone listens while the user speaks, and stops the recording once they are done.
        assistService.beginAudio(
            sampleRate: sampleRate,
            onStopRecording: { [weak self] in
                self?.stopRecording()
            },
            onFailure: { [weak self] error in
                self?.didFailToSendAudio(error)
            }
        )
    }

    @MainActor
    func didRecordAudio(_ audio: Data) {
        assistService.appendAudio(audio)
    }

    @MainActor
    func didStopRecording() {
        state = .waitingForPipelineResponse
        audioLevel = 0
        submitRecording()
    }

    func didCancelRecording() {
        assistService.cancelAudio()
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
        // The iPhone streams the recording into the run that failed, so there is nothing left to
        // send it to.
        audioRecorder.cancelRecording()
        // A failed round-trip is over too: return to idle so the keep-alive ping-pong stops.
        updateState(state: .idle)
    }

    func didReceiveAudioStreamStop(streamId: String) {
        assistService.phoneStoppedListening(streamId: streamId)
    }
}
