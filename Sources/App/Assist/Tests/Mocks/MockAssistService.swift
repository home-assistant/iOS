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

    func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void) {
        fetchPipelinesCalled = true
        completion(pipelineResponse)
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
}
