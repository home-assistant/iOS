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
    @Published var assistService: WatchAssistService
    @Published var showChatLoader = false

    private let audioRecorder: any WatchAudioRecorderProtocol
    private let immediateCommunicatorService: ImmediateCommunicatorService

    init(
        audioRecorder: any WatchAudioRecorderProtocol,
        assistService: WatchAssistService,
        immediateCommunicatorService: ImmediateCommunicatorService
    ) {
        self.audioRecorder = audioRecorder
        self.assistService = assistService
        self.immediateCommunicatorService = immediateCommunicatorService
        audioRecorder.delegate = self
        immediateCommunicatorService.addObserver(.init(delegate: self))
    }

    deinit {
        immediateCommunicatorService.removeObserver(self)
    }

    func assist() {
        audioRecorder.startRecording()
    }

    func stopRecording() {
        audioRecorder.stopRecording()
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
}

extension WatchAssistViewModel: WatchAudioRecorderDelegate {
    @MainActor
    func didStartRecording() {
        state = .recording
    }

    @MainActor
    func didStopRecording() {
        state = .waitingForPipelineResponse
    }

    @MainActor
    func didFinishRecording(audioURL: URL, audioSampleRate: Double) {
        sendAudioData(audioURL: audioURL, audioSampleRate: audioSampleRate)
        state = .waitingForPipelineResponse
    }

    func didFailRecording(error: any Error) {
        Current.Log.error("Failed to record Assist audio in watch App: \(error.localizedDescription)")
        state = .idle
    }
}

extension WatchAssistViewModel: ImmediateCommunicatorServiceDelegate {
    func didReceiveChatItem(_ item: AssistChatItem) {
        appendChatItem(item)
    }
}
