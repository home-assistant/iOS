import Foundation
import PromiseKit
import Shared

struct WatchPipeline {
    let id: String
    let name: String
}

final class WatchAssistViewModel: ObservableObject {
    enum State {
        case idle
        case recording
        case loading
        case waitingForPipelineResponse
    }

    @Published var chatItems: [AssistChatItem] = []
    @Published var state: State = .idle
    @Published var showChatLoader = false
    private var timer: Timer?

    private let audioRecorder: any WatchAudioRecorderProtocol
    private let audioPlayer: any AudioPlayerProtocol
    private let immediateCommunicatorService: ImmediateCommunicatorService

    @Published var assistService: WatchAssistService

    init(
        assistService: WatchAssistService,
        audioRecorder: any WatchAudioRecorderProtocol,
        audioPlayer: any AudioPlayerProtocol,
        immediateCommunicatorService: ImmediateCommunicatorService
    ) {
        self.audioRecorder = audioRecorder
        self.immediateCommunicatorService = immediateCommunicatorService
        self.assistService = assistService
        self.audioPlayer = audioPlayer
        audioRecorder.delegate = self
        immediateCommunicatorService.addObserver(.init(delegate: self))
    }

    deinit {
        endRoutine()
    }

    func initialRoutine() {
        assist()
    }

    /// (Re)subscribe to phone responses. Called on every appearance: `endRoutine()` unsubscribes
    /// when the view disappears (volume screen push, dismissal), so a view model that returns to
    /// the screen must register again or it stays deaf to STT/intent/TTS responses. Remove first
    /// so repeated appearances can't stack duplicate deliveries.
    func reconnectObserver() {
        immediateCommunicatorService.removeObserver(self)
        immediateCommunicatorService.addObserver(.init(delegate: self))
    }

    func endRoutine() {
        stopRecording()
        assistService.endRoutine()
        timer?.invalidate()
        immediateCommunicatorService.removeObserver(self)
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
