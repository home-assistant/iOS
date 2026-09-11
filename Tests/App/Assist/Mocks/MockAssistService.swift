import Foundation
@testable import HomeAssistant
import Shared

final class MockAssistService: AssistServiceProtocol {
    weak var delegate: AssistServiceDelegate?
    var pipelineResponse: PipelineResponse?
    var fetchPipelinesCalled: Bool = false
    var sendAudioDataCalled: Bool = false
    var assistSource: AssistSource?
    var audioDataSent: Data?
    var finishSendingAudioCalled = false
    var replacedServer: Shared.Server?
    var shouldStartListeningAgainAfterPlaybackEnd: Bool = false
    var resetShouldStartListeningAgainAfterPlaybackEndCalled: Bool = false
    var holdsPipelinesCompletion = false
    private var pendingPipelinesCompletion: ((PipelineResponse?) -> Void)?

    func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void) {
        fetchPipelinesCalled = true
        if holdsPipelinesCompletion {
            pendingPipelinesCompletion = completion
        } else {
            completion(pipelineResponse)
        }
    }

    func completePendingPipelinesFetch() {
        let completion = pendingPipelinesCompletion
        pendingPipelinesCompletion = nil
        completion?(pipelineResponse)
    }

    func replaceServer(server: Shared.Server) {
        replacedServer = server
    }

    func assist(source: AssistSource) {
        assistSource = source
    }

    func sendAudioData(_ data: Data) {
        sendAudioDataCalled = true
        audioDataSent = data
    }

    func finishSendingAudio() {
        finishSendingAudioCalled = true
    }

    func resetShouldStartListeningAgainAfterPlaybackEnd() {
        resetShouldStartListeningAgainAfterPlaybackEndCalled = true
    }
}
