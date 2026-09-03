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
    }

    enum State {
        case idle
        case recording
        case loading
        case waitingForPipelineResponse
    }

    @Published var chatItems: [AssistChatItem] = []
    @Published var state: State = .idle
    /// Normalized microphone input level (0...1) driving the voice orb while recording
    @Published var audioLevel: Double = 0
    @Published var showChatLoader = false
    private var timer: Timer?

    private let audioRecorder: any WatchAudioRecorderProtocol
    private let audioPlayer: any AudioPlayerProtocol
    private let immediateCommunicatorService: ImmediateCommunicatorService
    /// Keeps the app running through a wrist-down while the Assist screen is up, so a pipeline
    /// round-trip finishes (and TTS plays) even when the display has gone dark.
    private let runtimeSessions: WatchExtendedRuntimeSessionHolding
    /// Written prompt of an Assist prompt item: the session sends it instead of listening. `nil`
    /// for a regular voice session.
    private let prompt: String?

    @Published var assistService: WatchAssistService

    init(
        assistService: WatchAssistService,
        audioRecorder: any WatchAudioRecorderProtocol,
        audioPlayer: any AudioPlayerProtocol,
        immediateCommunicatorService: ImmediateCommunicatorService,
        runtimeSessions: WatchExtendedRuntimeSessionHolding = WatchExtendedRuntimeSessionManager.shared,
        prompt: String? = nil
    ) {
        self.audioRecorder = audioRecorder
        self.immediateCommunicatorService = immediateCommunicatorService
        self.runtimeSessions = runtimeSessions
        self.assistService = assistService
        self.audioPlayer = audioPlayer
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

    /// Hold the extended runtime session for as long as the screen is showing. Called on every
    /// appearance, as `endRoutine()` releases it whenever the screen goes away (volume push included).
    func beginExtendedRuntime() {
        runtimeSessions.begin(.assist)
    }

    func endRoutine() {
        stopRecording()
        assistService.endRoutine()
        timer?.invalidate()
        immediateCommunicatorService.removeObserver(self)
        runtimeSessions.end(.assist)
    }

    func assist() {
        if assistService.deviceReachable {
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
        Communicator.shared.send(.init(identifier: InteractiveImmediateMessages.ping.rawValue, reply: { _ in
            Current.Log.verbose("Pong from iPhone")
        }))
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

    func didReceiveError(code: String, message: String) {
        Current.Log.error("Watch Assist error: \(code)")
        appendChatItem(.init(content: message, itemType: .error))
        stopRecording()
        // A failed round-trip is over too: return to idle so the keep-alive ping-pong stops.
        updateState(state: .idle)
    }
}
