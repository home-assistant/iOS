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

        setupCommunicator()
    }
    
    func assist() {
            audioRecorder.startRecording()
    }

    func stopRecording() {
        audioRecorder.stopRecording()
    }

    private func setupCommunicator() {
        ImmediateMessage.observe { [weak self] message in
            guard let messageId = InteractiveImmediateResponses(rawValue: message.identifier) else {
                Current.Log.error("Received communicator message that cant be mapped to messages responses enum")
                return
            }

            switch messageId {
            case .assistSTTResponse:
                guard let content = message.content["content"] as? String else {
                    Current.Log.error("Received assistSTTResponse without content")
                    return
                }
                self?.appendChatItem(AssistChatItem(content: content, itemType: .input))
            case .assistIntentEndResponse:
                guard let content = message.content["content"] as? String else {
                    Current.Log.error("Received assistIntentEndResponse without content")
                    return
                }
                self?.appendChatItem(AssistChatItem(content: content, itemType: .output))
            case .assistTTSResponse:
                break
            default:
                break
            }
        }
    }

    private func sendAudioData(audioURL: URL, audioSampleRate: Double) {
        assistService.assist(audioURL: audioURL, sampleRate: audioSampleRate) { success in
            Current.Log.info("sendAudioData result: \(success)")
        }
    }

    private func appendChatItem(_ item: AssistChatItem) {
        DispatchQueue.main.async { [weak self] in
            self?.chatItems.append(item)
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
