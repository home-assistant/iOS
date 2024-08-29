import Communicator
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

    @Published var chatItems: [AssistChatItem] = [.init(content: "BETA", itemType: .info)]
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

    func endRoutine() {
        stopRecording()
        assistService.endRoutine()
        timer?.invalidate()
        immediateCommunicatorService.removeObserver(self)
    }

    func assist() {
        if assistService.deviceReachable {
            // Extra message just to wake up iPhone from the background
            Communicator.shared.send(ImmediateMessage(identifier: "wakeup"))
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
            self?.chatItems.append(item)
            self?.showChatLoader = false
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
    }

    func didReceiveTTS(url: URL) {
        audioPlayer.play(url: url)
    }

    func didReceiveError(code: String, message: String) {
        Current.Log.error("Watch Assist error: \(code)")
        appendChatItem(.init(content: message, itemType: .error))
        stopRecording()
    }
}
