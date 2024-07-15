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

    @Published var chatItems: [AssistChatItem] = []
    @Published var state: State = .idle
    @Published var showChatLoader = false
    @Published var showSettings = false

    private let audioRecorder: any WatchAudioRecorderProtocol
    private let audioPlayer: any AudioPlayerProtocol
    private let immediateCommunicatorService: ImmediateCommunicatorService

    @Published var assistService: WatchAssistService

    init(
        audioRecorder: any WatchAudioRecorderProtocol,
        audioPlayer: any AudioPlayerProtocol,
        immediateCommunicatorService: ImmediateCommunicatorService
    ) {
        self.audioRecorder = audioRecorder
        self.immediateCommunicatorService = immediateCommunicatorService
        self.assistService = WatchAssistService()
        self.audioPlayer = audioPlayer
        audioRecorder.delegate = self
        immediateCommunicatorService.addObserver(.init(delegate: self))
    }

    deinit {
        endRoutine()
    }

    func initialRoutine() {
        appendChatItem(.init(content: "BETA", itemType: .info))
        state = .loading
        guard !assistService.selectedServer.isEmpty else {
            fatalError("Server can't be nil")
        }
        if assistService.pipelines.isEmpty || assistService.preferredPipeline.isEmpty {
            Current.Log.info("Watch Assist: pipelines list is empty, trying to fetch pipelines")
            assistService.fetchPipelines { [weak self] success in
                Current.Log
                    .info("Watch Assist: Pipelines fetch done, result: \(success), moving on with assist command")
                if success {
                    self?.assist()
                } else {
                    self?.state = .idle
                }
            }
        } else {
            Current.Log.info("Watch Assist: pipelines list exist, moving on with assist command")
            assist()
        }
    }

    func endRoutine() {
        stopRecording()
        assistService.endRoutine()
        immediateCommunicatorService.removeObserver(self)
    }

    func assist() {
        guard !showSettings else {
            state = .idle
            stopRecording()
            return
        }
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

extension WatchAssistViewModel: WatchAudioRecorderDelegate {
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
