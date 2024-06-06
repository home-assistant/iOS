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

    private let audioRecorder: any WatchAudioRecorderProtocol

    init(
        audioRecorder: any WatchAudioRecorderProtocol,
        assistService: WatchAssistService
    ) {
        self.audioRecorder = audioRecorder
        self.assistService = assistService
        audioRecorder.delegate = self
    }

    func assist() {
        #if DEBUG
        chatItems.append(.init(content: "Hello", itemType: .input))
        #endif
        audioRecorder.startRecording()
    }

    private func sendAudioData(data: Data, audioSampleRate: Double) {
        assistService.assist(data: data, sampleRate: audioSampleRate) { success in
            print(success)
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
        do {
            let data = try Data(contentsOf: audioURL)
            sendAudioData(data: data, audioSampleRate: audioSampleRate)
        } catch {
            Current.Log.error("Failed to generate data from audioURL")
        }
        state = .waitingForPipelineResponse
    }

    func didFailRecording(error: any Error) {
        Current.Log.error("Failed to record Assist audio in watch App: \(error.localizedDescription)")
        state = .idle
    }
}
