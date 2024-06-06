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

    private let audioRecorder: any WatchAudioRecorderProtocol

    init(
        audioRecorder: any WatchAudioRecorderProtocol
    ) {
        self.audioRecorder = audioRecorder
        audioRecorder.delegate = self
    }

    func assist() {
        #if DEBUG
        chatItems.append(.init(content: "Hello", itemType: .input))
        #endif
        audioRecorder.startRecording()
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
    func didFinishRecording(audioURL: URL) {
        state = .waitingForPipelineResponse
    }

    func didFailRecording(error: any Error) {
        Current.Log.error("Failed to record Assist audio in watch App: \(error.localizedDescription)")
        state = .idle
    }
}
